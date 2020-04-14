require 'cfn-leaprog/cloudtrail/cloud_formation_with_role'
require 'cfn-leaprog/cloudformation'
require 'docker-compose'

describe CloudFormationConvergerWithRole do
  # localstack cfn is blowing up and worthless
  # before(:all) do
  #   @compose = DockerCompose.load 'spec/cloudtrail/localstack.yml'
  #   @compose.start 'localstack'
  #   sleep 10
  #   @iam = Aws::IAM::Client.new(endpoint: 'http://localhost:4593')
  #   @cfn = Aws::CloudFormation::Client.new(endpoint: 'http://localhost:4581')
  # end
  #
  # after(:all) do
  #   @compose.stop 'localstack'
  # end
  before(:all) do
    @iam = Aws::IAM::Client.new
    @cfn = Aws::CloudFormation::Client.new
  end

  it 'does not blow up on create' do
    cfn_converger_with_role = CloudFormationConvergerWithRole.new(@iam, @cfn)
    admin_role_arn = cfn_converger_with_role.converge_template(
      template_string: IO.read('spec/test_templates/DynamoDB_Table.template'),
      parameters: CloudFormation.convert_parameters(IO.read('spec/test_templates/parameters/ddb.json'))
    )
    expect(admin_role_arn).to match /arn:aws:iam::\d+:role\/cfn-leaprog-\d+/
  end

  it 'does not blow up on update', :update do
    cfn_converger_with_role = CloudFormationConvergerWithRole.new(@iam, @cfn)
    admin_role_arn = cfn_converger_with_role.converge_and_update_template(
      create_template_string: IO.read('spec/test_templates/DynamoDB_Table.template'),
      create_parameters: CloudFormation.convert_parameters(IO.read('spec/test_templates/parameters/ddb.json')),
      update_template_string: IO.read('spec/test_templates/DynamoDB_Table2.template'),
      update_parameters: CloudFormation.convert_parameters(IO.read('spec/test_templates/parameters/ddb2.json'))
    )
    expect(admin_role_arn).to match /arn:aws:iam::\d+:role\/cfn-leaprog-\d+/
  end
end