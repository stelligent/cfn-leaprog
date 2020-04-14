require 'cfn-leaprog/cloudtrail/cloudwatch_logs_event_filter'
require 'docker-compose'
require 'json'

def create_table(dynamo)
  dynamo.create_table(
    table_name: 'cfn-leaprog',
    attribute_definitions:[
      {
        attribute_name: "RoleArn",
        attribute_type: "S",
      }
    ],
    key_schema:[
      {
        attribute_name: "RoleArn",
        key_type: "HASH",
      }
    ],
    provisioned_throughput: {
      read_capacity_units: 5,
      write_capacity_units: 5,
    }
  )
end

describe 'handler' do
  context 'cwl event received' do
    before(:all) do
      @compose = DockerCompose.load 'spec/cloudtrail/local_dynamo.yml'
      @compose.start 'db'

      @dynamo = Aws::DynamoDB::Client.new(endpoint: 'http://localhost:8000')
      create_table(@dynamo)
      @events_dao = EventsDao.new(
        @dynamo,
        'cfn-leaprog'
      )
    end

    after(:all) do
      @compose.stop 'db'
    end

    it 'ignores events that are not from CloudFormation' do
      ENV['TABLE_NAME'] = 'cfn-leaprog'
      event_filter = CloudWatchLogsEventFilter.new
      allow(event_filter).to receive(:dynamodb).and_return(@dynamo)
      allow(event_filter).to receive(:uncompressed_log_events).and_return(
        [
          {
            'message' => {
              'userIdentity' => {
                'principalId' => 'fred',
                'sessionContext' => {
                  'sessionIssuer' => {
                    'arn' => 'cfn-leaprog'
                  }
                }
              },
              'sourceIPAddress' => 's3.amazonaws.com'
            }.to_json
          }
        ]
      )
      event_filter.filter(nil)

      scan_response = @dynamo.scan(
        table_name: ENV['TABLE_NAME']
      )
      expect(scan_response.items.size).to eq 0
    end

    it 'ignores events that are not from an cfn-leaprog' do
      ENV['TABLE_NAME'] = 'cfn-leaprog'
      event_filter = CloudWatchLogsEventFilter.new
      expect(event_filter).to receive(:dynamodb).and_return(@dynamo)
      expect(event_filter).to receive(:uncompressed_log_events).and_return(
        [
          {
            'message' => {
              'userIdentity' => {
                'type' => 'AssumedRole',
                'principalId' => 'abzcd:AWSCloudFormation',
                'sessionContext' => {
                  'sessionIssuer' => {
                    'arn' => 'notmoo'
                  }
                }
              }
            }.to_json
          }
        ]
      )
      expect(event_filter).to_not receive(:create_event)

      event_filter.filter(nil)

      scan_response = @dynamo.scan(
        table_name: ENV['TABLE_NAME']
      )
      expect(scan_response.items.size).to eq 0
    end

    it 'stores events in ddb for events from an cfn-leaprog' do
      ENV['TABLE_NAME'] = 'cfn-leaprog'
      event_filter = CloudWatchLogsEventFilter.new
      expect(event_filter).to receive(:dynamodb).and_return(@dynamo)
      expect(event_filter).to receive(:uncompressed_log_events).and_return(
        [
          {
            'message' => {
              'userIdentity' => {
                'type' => 'AssumedRole',
                'principalId' => 'fdsdcasassa:AWSCloudFormation',
                'sessionContext' => {
                  'sessionIssuer' => {
                    'arn' => 'arn:aws:iam::1111111111:role/cfn-leaprog-2342322'
                  }
                }
              },
              'eventTime' => '2020-03-26T18:34:13Z',
              'eventSource' => 'dynamodb.amazonaws.com',
              'eventName' => 'CreateTable',
              'resources' => [
                {
                  'accountId' => '1111111111',
                  'type' => 'AWS::DynamoDB::Table',
                  'ARN' => 'arn:aws:dynamodb:us-east-1:1111111111111111:table/cfn-least-privilege-role-generator1585247650-myDynamoDBTable-1CO4HWYNMCN3Q'
                }
              ]
            }.to_json
          },
          {
            'message' => {
              'userIdentity' => {
                'type' => 'AssumedRole',
                'principalId' => 'fdsdcasassa:AWSCloudFormation',
              'sessionContext' => {
                  'sessionIssuer' => {
                    'arn' => 'arn:aws:iam::1111111111:role/cfn-leaprog-2342322'
                  }
                }
              },
              'eventTime' => '2020-03-26T18:34:13Z',
              'eventSource' => 'dynamodb.amazonaws.com',
              'eventName' => 'DescribeTable',
              'resources' => [
                {
                  'accountId' => '1111111111',
                  'type' => 'AWS::DynamoDB::Table',
                  'ARN' => 'arn:aws:dynamodb:us-east-1:1111111111111111:table/cfn-least-privilege-role-generator1585247650-myDynamoDBTable-1CO4HWYNMCN3Q'
                }
              ]
            }.to_json
          }
        ]
      )
      event_filter.filter(nil)

      events = @events_dao.events 'arn:aws:iam::1111111111:role/cfn-leaprog-2342322'
      expect(events.size).to eq 2
    end
  end
end