require 'aws-sdk-dynamodb'

class EventsDao
  def initialize(dynamo, table_name)
    @table_name = table_name
    @dynamo = dynamo
  end

  ##
  # Correlate the iam_role_arn with an event.
  #
  # If no record is found, create it.  Otheriwse, append the event
  # to the Event attribute.
  #
  def create_event(iam_role_arn:, event_name:, event_time:, event_source:, resources:, request_parameters:)
    _ = @dynamo.update_item(
      expression_attribute_values: {
        ':event' => [
          {
            'action' => event_name,
            'source' => event_source,
            'eventTime' => event_time,
            'resources' => resources,
            'requestParameters' => request_parameters
          }
        ],
        ':empty_list' => []
      },
      key: {
        'RoleArn' => iam_role_arn
      },
      table_name: @table_name,
      update_expression: 'SET Events = list_append(if_not_exists(Events, :empty_list), :event)'
    )
  end

  ##
  # Retrieve the events correlated with the iam_role_arn
  #
  # If no record exists, return an empty array
  #
  def events(iam_role_arn)
    get_item_response = @dynamo.get_item(
      key: {
        'RoleArn' => iam_role_arn
      },
      table_name: @table_name
    )
    return [] unless get_item_response['item']
    get_item_response['item']['Events']
  end
end