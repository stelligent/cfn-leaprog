require 'cfn-least-privilege-role-generator/cloudtrail/cloudwatch_logs'

include CloudWatchLogs

describe CloudWatchLogs do
  it 'decodes and uncompresses the log events' do
    cloudwatch_log_event = {
      'awslogs' => {
        'data' => "H4sIAAAAAAAAAHWPwQqCQBCGX0Xm7EFtK+smZBEUgXoLCdMhFtKV3akI8d0bLYmibvPPN3wz00CJxmQnTO41whwWQRIctmEcB6sQbFC3CjW3XW8kxpOpP+OC22d1Wml1qZkQGtoMsScxaczKN3plG8zlaHIta5KqWsozoTYw3/djzwhpLwivWFGHGpAFe7DL68JlBUk+l7KSN7tCOEJ4M3/qOI49vMHj+zCKdlFqLaU2ZHV2a4Ct/an0/ivdX8oYc1UVX860fQDQiMdxRQEAAA=="
      }
    }
    actual_log_events = uncompressed_log_events(cloudwatch_log_event)
    expected_log_events =[
      {
        'id' => 'eventId1',
        'message' => '[ERROR] First test message',
        'timestamp' =>1440442987000
      },
      {
        'id' => 'eventId2',
        'message' => '[ERROR] Second test message',
        'timestamp' =>1440442987001
      }
    ]
    expect(actual_log_events).to eq expected_log_events
  end
end