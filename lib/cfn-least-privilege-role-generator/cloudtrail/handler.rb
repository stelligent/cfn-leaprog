require_relative '../logging'
require_relative 'cloudwatch_logs_event_filter'
require 'logger'

##
# This handler is going to parse CloudTrail events that are sent to CloudWatch Logs.
#
# The SubscriptionFilter: {$.sourceIPAddress = cloudformation.amazonaws.com}
# is serving as a gate to the flood of CloudTrail events hitting the CloudWatch LogGroup
# this is subscribed to
#
# For each log event, update item in dynamodb with the IAM role key, and all the
# events using that role.
#
def handler(event:, context:)
  Logging.logger.level = Logger::DEBUG
  CloudWatchLogsEventFilter.new.filter(event)
end
