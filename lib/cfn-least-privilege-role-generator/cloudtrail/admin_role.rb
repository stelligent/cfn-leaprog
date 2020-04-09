require 'aws-sdk-iam'
require 'json'

class AdminRole

  POLICY_NAME = 'admin-policy'

  def create(iam_client:, role_name:)
    role_arn = create_role_and_wait(iam_client: iam_client, role_name: role_name)
    put_admin_policy_and_wait(iam_client: iam_client, role_name: role_name)
    # i dunno, even waiting and getting real feedback it's there - still seems to not work sometimes???
    sleep 15
    role_arn
  end

  def delete(iam_client:, role_name:)
    iam_resource = Aws::IAM::Resource.new(client: iam_client)
    role = iam_resource.role(role_name)
    role.policies.each do |policy|
      policy.delete
    end
    role.delete
  end

  private

  def put_admin_policy_and_wait(iam_client:, role_name:)
    _ = iam_client.put_role_policy(
      policy_document: admin_policy,
      policy_name: POLICY_NAME,
      role_name: role_name
    )

    wait_for_put_role_policy(
      iam_client: iam_client,
      role_name: role_name
    )
  end

  def wait_for_put_role_policy(iam_client:, role_name:)
    while true do
      begin
        _ = iam_client.get_role_policy(
          role_name: role_name,
          policy_name: POLICY_NAME
        )
        break
      rescue
        sleep 10
      end
    end
  end

  def admin_policy
    <<END
{
  "Version":"2012-10-17",
  "Statement":{
    "Effect": "Allow",
    "Action": "*",
    "Resource":"*"
  }
}
END
  end

  def cloudformation_trust_policy
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

  def create_role_and_wait(iam_client:,
                           role_name:)

    create_role_response = iam_client.create_role(
      assume_role_policy_document: cloudformation_trust_policy,
      role_name: role_name
    )

    iam_client.wait_until(
      :role_exists,
      role_name: role_name
    )
    create_role_response[:role][:arn]
  end
end