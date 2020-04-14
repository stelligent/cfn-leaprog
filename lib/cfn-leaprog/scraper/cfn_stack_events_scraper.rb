class CfnStackEventsScraper
  def initialize
    register_event_patterns
  end

  # User: arn:aws:sts::1111111111111111:assumed-role/cfn-leaprog/AWSCloudFormation is not authorized to perform: dynamodb:CreateTable on resource: arn:aws:dynamodb:us-east-1:1111111111111111:table/cfn-leaprog-1584734634-myDynamoDBTable-1W4RS7WY06QYM (Service: AmazonDynamoDBv2; Status Code: 400; Error Code: AccessDeniedException; Request ID: CQL55J3ESGNU65J9JCS5G1TMTVVV4KQNSO5AEMVJF66Q9ASUAAJG)
  # Did not have IAM permissions to process tags on AWS::SNS::Topic resource.
  # Failed to check if policy already exists due to lack of getGroupPolicy permission, you might be overriding or adopting an existing policy on this Group
  # Did not have IAM permissions to process tags on AWS::IAM::User resource
  # API: sqs:CreateQueue Access to the resource https://sqs.us-east-1.amazonaws.com/ is denied.
  # API: iam:ListAccessKeys User: arn:aws:sts::1111111111111111:assumed-role/cfn-leaprog/AWSCloudFormation is not authorized to perform: iam:ListAccessKeys on resource: user cfn-leaprog-1584472669-MyQueueUser-C4PXC4LOC6I3
  def missing_actions_and_resources(events_to_scrape:)
    missing_action_names = []
    missing_resource_names = []

    events_to_scrape.each do |event|
      next if event.resource_status_reason.nil?

      @event_patterns.each do |event_pattern|
        match_result = event.resource_status_reason.match event_pattern.regex
        if match_result
          parsed_result = event_pattern.parse_result(match_result)
          missing_action_names += parsed_result[:actions]
          missing_resource_names += parsed_result[:resources]
          break
        end
      end
    end
    [missing_action_names, missing_resource_names]
  end

  private

  class ResourceAccessDenied
    def regex
      /API: (.*) Access to the resource (.*) is denied./
    end

    def parse_result(result)
      {
        actions: [result[1]],
        resources: ["#{service_name(result[1])}:*"]
      }
    end

    def service_name(api_call)
      api_call.split(':')[0]
    end
  end

  class ResourceAccessDenied2
    def regex
      /API: (.*) Access Denied/
    end

    def parse_result(result)
      {
        actions: [result[1]],
        resources: ["#{service_name(result[1])}:*"]
      }
    end

    def service_name(api_call)
      api_call.split(':')[0]
    end
  end

  class S3BucketCreation
    def regex
      /API: s3:CreateBucket Access Denied/
    end

    def parse_result(result)
      {
        # this message showing up the eventrace can hide a whole bunch of operations
        # best effort here
        actions: %w[s3:CreateBucket s3:PutBucket* s3:GetBucket*],
        resources: ['s3:*']
      }
    end

    def service_name(api_call)
      api_call.split(':')[0]
    end
  end

  class GetRolePolicyMissing
    def regex
      /Failed to check if policy already exists due to lack of getRolePolicy permission, you might be overriding or adopting an existing policy on this Role/
    end

    def parse_result(result)
      {
        actions: %w[iam:GetRolePolicy],
        resources: []
      }
    end
  end

  class GetGroupPolicyMissing
    def regex
      /Failed to check if policy already exists due to lack of getGroupPolicy permission, you might be overriding or adopting an existing policy on this Group/
    end

    def parse_result(result)
      {
        actions: %w[iam:GetGroupPolicy],
        resources: []
      }
    end
  end

  class UserNotAuthorized1
    def regex
      /API: (.*) User: (.*) is not authorized to perform: (.*) on resource: (.*)/
    end

    def parse_result(result)
      {
        actions: [result[1], result[3]],
        resources: [result[4]]
      }
    end
  end

  class UserNotAuthorized2
    def regex
      /User: (.*) is not authorized to perform: (.*) on resource: ([^\s]+) /
    end

    def parse_result(result)
      {
        actions: [result[2]],
        resources: [result[3]]
      }
    end
  end

  class UserNotAuthorized3
    def regex
      /AccessDenied. User doesn't have permission to call (.*). Rollback requested by user./
    end

    def parse_result(result)
      {
        actions: [result[1]],
        resources: ['ec2:*']
      }
    end
  end

  class UserNotAuthorized4
    def regex
      /API: (.*) You are not authorized to perform this operation./
    end

    def parse_result(result)
      {
        actions: [result[1]],
        resources: ['*']
      }
    end
  end

  class UserNotAuthorized5
    def regex
      /API: (.*) User: (.*) is not authorized to perform: (.*)$/
    end

    def parse_result(result)
      {
        actions: [result[3]],
        resources: ["#{service_name(result[3])}:*"]
      }
    end

    def service_name(api_call)
      api_call.split(':')[0]
    end
  end

  class TagActions
    def regex
      /Did not have IAM permissions to process tags on (.*) resource/
    end

    def parse_result(result)
      actions = cfn_resource_type_to_tag_actions[result[1]]
      {
        actions: actions ? actions : [],
        resources: []
      }
    end
  end

  def service_name(api_call)
    api_call.split(':')[0]
  end

  def describe_stack_events(stack_id)
    token = nil
    done = false
    events = []
    until done
      describe_stack_events_response = cfn_client.describe_stack_events(
        stack_name: stack_id,
        next_token: token
      )
      events += describe_stack_events_response.stack_events
      token = describe_stack_events_response.next_token
      done = true unless token
    end
    events
  end

  def register_event_patterns
    @event_patterns = [
      GetGroupPolicyMissing.new,
      UserNotAuthorized1.new,
      UserNotAuthorized2.new,
      UserNotAuthorized3.new,
      UserNotAuthorized4.new,
      UserNotAuthorized5.new,
      TagActions.new,
      ResourceAccessDenied.new,
      ResourceAccessDenied2.new,
      S3BucketCreation.new,
      GetRolePolicyMissing.new
    ]
  end

  def cfn_resource_type_to_tag_actions
    {
      # much to fill in here if we didn't abandon this approach....
      'AWS::AccessAnalyzer::Analyzer' => %w[],
      'AWS::ACMPCA::CertificateAuthority' => %w[],
      'AWS::AmazonMQ::Broker' => %w[],
      'AWS::AmazonMQ::Configuration' => %w[],
      'AWS::Amplify::App' => %w[],
      'AWS::Amplify::Branch' => %w[],
      'AWS::ApiGateway::ApiKey' => %w[],
      'AWS::IAM::User' => %w[iam:ListUserTags iam:TagUser iam:UntagUser],
      'AWS::SNS::Topic' => %w[sns:ListTagsForResource sns:TagResource sns:UntagResource],
      'AWS::SQS::Queue' => %w[sqs:ListQueueTags sqs:TagQueue sqs:UntagQueue],
      'AWS::S3::Bucket' => %w[s3:PutBucketTagging s3:GetBucketTagging]
    }
  end
end
