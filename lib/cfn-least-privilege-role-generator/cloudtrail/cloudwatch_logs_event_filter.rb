require 'aws-sdk-dynamodb'
require 'json'
require_relative 'cloudwatch_logs'
require_relative 'events_dao'
require_relative '../logging'

##
# This is the heart of the Lambda with not the greatest name....
# it takes a CloudWatch Logs Event that came from CloudTrail....
# and if it matches our pattern for assumed IAM role, selects a few
# fields from the event and stores it in a DynamoDB with the IAM role
# ARN being the key
#
# The PolicyGenerator.policy_from_dynamodb is the client
# for this information
#
class CloudWatchLogsEventFilter
  include CloudWatchLogs
  include Logging

  def filter(cloudwatch_logs_event)
    events_dao = EventsDao.new(
      dynamodb,
      ENV['TABLE_NAME']
    )

    uncompressed_log_events(cloudwatch_logs_event).each do |cloudformation_cloudtrail_event|
      logger.debug("cloudformation_cloudtrail_event: #{cloudformation_cloudtrail_event}")

      message = JSON.parse(cloudformation_cloudtrail_event['message'])

      iam_role_arn = message['userIdentity']['sessionContext']['sessionIssuer']['arn']
      next unless generator_role_arn?(iam_role_arn)
      next unless cloudformation_source?(message)

      create_event(
        events_dao: events_dao,
        iam_role_arn: iam_role_arn,
        message: message
      )
    end
  end

  private

  def cloudformation_source?(message)
    message['userIdentity']['principalId'].match(/.*AWSCloudFormation.*/) || message['sourceIPAddress'] == 'cloudformation.amazonaws.com'
  end

  def generator_role_arn?(iam_role_arn)
    iam_role_arn.match /.*cfn-least-privilege-role-generator.*/
  end

  def create_event(events_dao:, iam_role_arn:, message:)
    events_dao.create_event(
      iam_role_arn: iam_role_arn,
      event_name: message['eventName'],
      event_time: message['eventTime'],
      event_source: message['eventSource'],
      resources:  message['resources'],
      request_parameters: message['requestParameters']
    )
  end

  def dynamodb
    Aws::DynamoDB::Client.new
  end
end
