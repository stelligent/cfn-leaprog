# frozen_string_literal: true
require 'rake'
require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-iam'
require 'aws-sdk-cloudformation'
require_relative 'lib/cfn-leaprog/cloudformation'
require_relative 'lib/cfn-leaprog/policy_renderer'
require_relative 'lib/cfn-leaprog/scraper/scraper_least_privilege_role_generator'
require_relative 'lib/cfn-leaprog/cloudtrail/cloud_formation_converger_with_role'
require_relative 'lib/cfn-leaprog/cloudtrail/policy_generator'

namespace :scrape do
  desc 'Generate the least privilege IAM role to call CreateStack on a CloudFormation template by scraping cfn events'
  task :create_stack, :template_path, :parameters_path do |_, args|
    if args[:parameters_path]
      parameters_string = IO.read(args[:parameters_path])
      parameters = CloudFormation.convert_parameters(parameters_string)
      initial_actions = CloudFormation.initial_actions(parameters_string)
    else
      parameters = []
      initial_actions = nil
    end

    role_and_policy = ScraperLeastPrivilegeRoleGenerator.new.create_stack_role(
      template_string: IO.read(args[:template_path]),
      parameters: parameters,
      initial_actions: initial_actions
    )
    puts PolicyRenderer.new.render(role_and_policy)
  end

  desc 'Generate the least privilege IAM role to call UpdateStack on a CloudFormation template by scraping cfn events'
  task :update_stack, :base_template_path,
                      :base_parameters_path,
                      :target_template_path,
                      :target_parameters_path do |_, args|
    base_parameters_string = IO.read(args[:base_parameters_path])
    base_parameters = CloudFormation.convert_parameters(base_parameters_string)

    target_parameters_string = IO.read(args[:target_parameters_path])
    target_parameters = CloudFormation.convert_parameters(target_parameters_string)

    role_and_policy = ScraperLeastPrivilegeRoleGenerator.new.update_stack_role(
      create_template_string: IO.read(args[:base_template_path]),
      create_parameters: base_parameters,
      update_template_string: IO.read(args[:target_template_path]),
      update_parameters: target_parameters
    )
    puts PolicyRenderer.new.render(role_and_policy)
  end
end

########################

namespace :ct do
  desc 'Spin up the CloudTrail, CloudWatch Logs and Labmda infrastructure necessary to catch events for least-priv policy'
  task :infra do
    region = 'us-east-1'
    trail_stack_name = 'cfn-leaprog-trail'
    lambda_stack_name = 'cfn-leaprog-lambda'

    sh 'stack_master --yes apply'
    outputs = `stack_master outputs #{region} #{trail_stack_name}`
    result = outputs.match /LambdaBucket\s+\| (.*)\s+\|/
    lambda_bucket = result[1]

    sh "sam package --template-file templates/cloudtrail_events.template.yml --s3-bucket #{lambda_bucket} --output-template-file packaged.yaml"
    sh "sam deploy --template-file packaged.yaml --stack-name #{lambda_stack_name} --capabilities CAPABILITY_IAM"
  end

  desc 'Tear down the CloudTrail, CloudWatch Logs and Labmda infrastructure necessary to catch events for least-priv policy'
  task :teardown_infra do
    region = 'us-east-1'
    trail_stack_name = 'cfn-leaprog-trail'
    lambda_stack_name = 'cfn-leaprog-lambda'

    outputs = `stack_master outputs #{region} #{trail_stack_name}`
    result = outputs.match /CfnLeastPrivilegeRoleGeneratorBucket\s+\| (.*)\s+\|/
    log_bucket = result[1].strip
    sh "aws s3 rm --recursive s3://#{log_bucket}"
    result = outputs.match /LambdaBucket\s+\| (.*)\s+\|/
    lambda_bucket = result[1].strip
    sh "aws s3 rm --recursive s3://#{lambda_bucket}"

    sh "aws cloudformation delete-stack --stack-name #{lambda_stack_name}"
    sh "stack_master --yes  delete #{region} #{trail_stack_name}"
  end

  desc 'Generate the least privilege IAM policy on a CloudFormation template by parsing CloudTrail'
  task :policy, :iam_role_arn, :hide_request_parameters  do |_, args|
    dynamo = Aws::DynamoDB::Client.new
    role_and_policy, request_parameters = PolicyGenerator.new.policy_from_dynamodb(
      dynamo,
      args[:iam_role_arn]
    )
    if args[:hide_request_parameters] == 'true'
      request_parameters = nil
    end
    puts PolicyRenderer.new.render(role_and_policy, request_parameters)
  end

  desc 'Generate the least privilege IAM policy to create a CloudFormation template by parsing CloudTrail'
  task :create_stack, [:template_path, :parameters_path] do |_, args|
    if args[:parameters_path]
      parameters_string = IO.read(args[:parameters_path])
      parameters = CloudFormation.convert_parameters(parameters_string)
    else
      parameters = []
    end

    iam = Aws::IAM::Client.new
    cfn = Aws::CloudFormation::Client.new

    role_name = CloudFormationConvergerWithRole.new(iam, cfn).converge_template(
      template_string: IO.read(args[:template_path]),
      parameters: parameters
    )
    puts role_name
  end

  desc 'Generate the least privilege IAM policy to create/update a CloudFormation template by parsing CloudTrail'
  task :update_stack, [:base_template_path,
                      :base_parameters_path,
                      :target_template_path,
                      :target_parameters_path] do |_, args|
    base_parameters_string = IO.read(args[:base_parameters_path])
    base_parameters = CloudFormation.convert_parameters(base_parameters_string)

    target_parameters_string = IO.read(args[:target_parameters_path])
    target_parameters = CloudFormation.convert_parameters(target_parameters_string)

    iam = Aws::IAM::Client.new
    cfn = Aws::CloudFormation::Client.new

    role_name = CloudFormationConvergerWithRole.new(iam, cfn).converge_and_update_template(
      create_template_string: IO.read(args[:base_template_path]),
      create_parameters: base_parameters,
      update_template_string: IO.read(args[:target_template_path]),
      update_parameters: target_parameters
    )
    puts role_name
  end
end
