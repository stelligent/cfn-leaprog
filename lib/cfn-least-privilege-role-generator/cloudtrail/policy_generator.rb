require 'set'
require_relative '../policy'
require_relative '../logging'
require_relative 'events_dao'

class PolicyGenerator
  include Logging

  DDB_TABLE_NAME = 'cfn-least-privilege-role-generator-events'

  ##
  # Generate a Policy based upon what has been stored in the DynamoDB table
  # by the lambda handler that filtered CloudTrail events
  #
  def policy_from_dynamodb(dynamo, iam_role_arn)
    actions_set = Set.new
    resources_set = Set.new

    cloudtrail_events(dynamo, iam_role_arn).each do |cloudtrail_event|
      actions_set.add action(service_prefix(cloudtrail_event['source']), cloudtrail_event['action'])

      if cloudtrail_event['resources']
        cloudtrail_event['resources'].each do |resource|
          resources_set.add resource['ARN']
        end
      end
    end

    Policy.new.reorganize_statements_by_service(
      actions_set.to_a,
      resources_set.to_a
    )
  end

  private

  def cloudtrail_events(dynamo, iam_role_arn)
    events_dao = EventsDao.new(
      dynamo,
      DDB_TABLE_NAME
    )
    events_dao.events(iam_role_arn)
  end

  def service_prefix(source)
    source.split('.')[0]
  end

  def action(service, operation)
    "#{service}:#{operation}"
  end
end
