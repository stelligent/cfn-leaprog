require 'aws-sdk-iam'
require 'json'
require 'set'

class IamRole

  POLICY_NAME = 'some-policy'

  ##
  # deleting and recreating IAM roles with the same name is causing big bleeping trouble.
  # the inconsistent behavior is making me very very angry.
  # wipe out the policy instead
  def reset(iam_client:, role_name:)
    begin
      get_role_response = iam_client.get_role role_name: role_name
    rescue Aws::IAM::Errors::NoSuchEntity
      create_role_and_wait(iam_client: iam_client, role_name: role_name)
    end

    policy = force_null_policy(iam_client: iam_client, role_name: role_name)
    sleep 10
    {
      role: get_role_response.to_h[:role],
      policy: policy
    }
  end

  def converge(iam_client:, role_name:, actions:)
    policy = put_actions(
      iam_client: iam_client,
      role_name: role_name,
      actions: actions
    )
    sleep 10

    get_role_response = iam_client.get_role role_name: role_name
    {
      role: get_role_response.to_h[:role],
      policy: policy
    }
  end

  private

  def put_actions(iam_client:, role_name:, actions:)
    policy_document = <<END
{
  "Version":"2012-10-17",
  "Statement":{
    "Effect": "Allow",
    "Action": #{JSON.generate(actions)},
    "Resource":"*"
  }
}
END
    _ = iam_client.put_role_policy(
      policy_document: policy_document,
      policy_name: POLICY_NAME,
      role_name: role_name
    )

    policy_document = wait_for_put_role_policy(
      iam_client: iam_client,
      role_name: role_name,
      actions: actions
    )
    policy_document
  end

  def wait_for_put_role_policy(iam_client:, role_name:, actions:)
    actions_set = false
    while !actions_set do
      get_role_policy_response = iam_client.get_role_policy(
        role_name: role_name,
        policy_name: POLICY_NAME
      )
      policy_document = JSON.parse URI.decode_www_form_component(get_role_policy_response.policy_document)
      if policy_document['Statement']['Action'] == actions
        actions_set = true
      else
        sleep 10
      end
    end
    policy_document
  end

  def trust_policy()
    <<END
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudformation.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
END
  end

  def force_null_policy(iam_client:, role_name:)
    # without a policy, a role cannot be assumedd
    policy_document = put_actions(
      iam_client: iam_client,
      role_name: role_name,
      actions: %w(null:NullAction)
    )

    policy_document
  end

  def create_role_and_wait(iam_client:,
                           role_name:)

    _ = iam_client.create_role(
      assume_role_policy_document: trust_policy,
      role_name: role_name
    )

    iam_client.wait_until(
      :role_exists,
      role_name: role_name
    )
  end
end