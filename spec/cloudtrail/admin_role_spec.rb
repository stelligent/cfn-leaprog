require 'cfn-least-privilege-role-generator/cloudtrail/admin_role'
require 'aws-sdk-iam'
require 'docker-compose'
require 'json'

describe AdminRole do
  context 'roles does not yet exist' do
    before(:all) do
      @compose = DockerCompose.load 'spec/cloudtrail/localstack.yml'
      @compose.start 'localstack'
      sleep 15
      @iam = Aws::IAM::Client.new(endpoint: 'http://localhost:4593')
    end

    after(:all) do
      @compose.stop 'localstack'
    end

    it 'creates and deletes the role' do
      admin_role = AdminRole.new
      admin_role.create(
        iam_client: @iam,
        role_name: 'moocow1234'
      )

      get_role_response = @iam.get_role(role_name: 'moocow1234')
      actual_trust_policy = JSON.parse(get_role_response['role']['assume_role_policy_document'])
      expected_trust_policy_principal = 'cloudformation.amazonaws.com'
      expect(actual_trust_policy['Statement'][0]['Principal']['Service']).to eq expected_trust_policy_principal

      get_role_policy_response = @iam.get_role_policy(role_name: 'moocow1234', policy_name: 'admin-policy')
      actual_policy_document = JSON.parse(get_role_policy_response.policy_document)
      expected_policy_document_action = '*'
      expect(actual_policy_document['Statement']['Action']).to eq expected_policy_document_action

      admin_role.delete(iam_client: @iam, role_name: 'moocow1234')
      expect {
        _ = @iam.get_role(role_name: 'moocow1234')
      }.to raise_error Aws::IAM::Errors::NoSuchEntity
    end
  end
end
