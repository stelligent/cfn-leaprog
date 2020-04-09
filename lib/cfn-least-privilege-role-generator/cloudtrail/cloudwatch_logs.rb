require 'json'
require 'base64'
require 'zlib'
require 'stringio'

module CloudWatchLogs
  def uncompressed_log_events(cloudwatch_log_event)
    decoded_data = Base64.strict_decode64(cloudwatch_log_event['awslogs']['data'])
    gzip_reader = Zlib::GzipReader.new(StringIO.new(decoded_data))
    uncompressed_events_str = gzip_reader.read
    uncompressed_events = JSON.parse(uncompressed_events_str)
    uncompressed_events['logEvents']
  end
end