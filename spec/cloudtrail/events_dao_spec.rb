require 'cfn-least-privilege-role-generator/cloudtrail/events_dao'
require 'docker-compose'

def create_table(dynamo)
  dynamo.create_table(
    table_name: 'DONTCARE',
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

describe EventsDao do
  context 'empty db' do
    before(:all) do
      @compose = DockerCompose.load 'spec/cloudtrail/local_dynamo.yml'
      @compose.start 'db'

      @dynamo = Aws::DynamoDB::Client.new(endpoint: 'http://localhost:8000')
      create_table(@dynamo)
      @events_dao = EventsDao.new(
        @dynamo,
        'DONTCARE'
      )
    end

    after(:all) do
      @compose.stop 'db'
    end

    describe '#events' do
      it 'does what' do
        actual_events = @events_dao.events('wontfindmegarbage')
        expected_events = []
        expect(actual_events).to eq expected_events
      end
    end

    describe '#create_event' do
      it 'creates an entry' do
        @events_dao.create_event(
          iam_role_arn: 'arn:aws::iam:role/FooRole',
          event_name: 'DoSomething',
          event_time: Time.now.to_s,
          event_source: 'myservice.amazonaws.com',
          resources: [
            {
              'Fred' => 'Wilma'
            }
          ]
        )

        events = @events_dao.events'arn:aws::iam:role/FooRole'
        expect(events.size).to eq 1
        expect(events[0]['source']).to eq 'myservice.amazonaws.com'
        expect(events[0]['action']).to eq 'DoSomething'
        expect(events[0]['resources']).to eq(
          [
            {
              'Fred' => 'Wilma'
            }
          ]
        )
      end
    end
  end

  context 'db with record' do
    before(:all) do
      @compose = DockerCompose.load 'spec/cloudtrail/local_dynamo.yml'
      @compose.start 'db'

      @dynamo = Aws::DynamoDB::Client.new(endpoint: 'http://localhost:8000')
      create_table(@dynamo)
      put_item_response = @dynamo.put_item(
        item: {
          'RoleArn' => 'arn:aws::iam:role/FooRole',
          'Events' => [
            {
              'action' => 'DoSomething',
              'source' => 'myservice.amazonaws.com',
              'eventTime' => Time.now.to_s,
              'resources' => [
                {
                  'Fred' => 'Wilma'
                }
              ]
            }
          ]
        },
        return_consumed_capacity: "TOTAL",
        table_name: 'DONTCARE'
      )
    end

    after(:all) do
      @compose.stop 'db'
    end

    describe '#create_event' do
      it 'updates an entry' do
        events_dao = EventsDao.new(
          @dynamo,
          'DONTCARE'
        )

        events_dao.create_event(
          iam_role_arn: 'arn:aws::iam:role/FooRole',
          event_name: 'DoSomething2',
          event_time: Time.now.to_s,
          event_source: 'myservice2.amazonaws.com',
          resources: [
            {
              'Fred2' => 'Wilma2'
            }
          ]
        )

        events = events_dao.events'arn:aws::iam:role/FooRole'
        expect(events.size).to eq 2
      end
    end
  end
end