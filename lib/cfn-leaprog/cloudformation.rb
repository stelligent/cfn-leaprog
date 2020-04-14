require 'aws-sdk-cloudformation'
require 'json'

module CloudFormation
  WAIT = 250

  def cfn_resource(cfn_client)
    Aws::CloudFormation::Resource.new(client: cfn_client)
  end

  def delete_stack_and_wait(cfn_client, stack)
    cfn_client.delete_stack(
      stack_name: stack.name
    )
    begin
      stack.wait_until(max_attempts:WAIT, delay:20) do |instance|
        !instance.stack_status.match /^.*_IN_PROGRESS$/
      end
    rescue
    end
  end

  def update_stack_and_wait(cfn_client:, stack_name:, template_string:, parameters:, role_arn:)
    update_stack_response = cfn_client.update_stack(
      stack_name: stack_name,
      template_body: template_string,
      parameters: parameters,
      capabilities: %w(CAPABILITY_NAMED_IAM),
      role_arn: role_arn
    )
    stack_id = update_stack_response.stack_id
    stack = cfn_resource(cfn_client).stack(stack_id)
    begin
      stack.wait_until(max_attempts:WAIT, delay:20) do |instance|
        !instance.stack_status.match /^.*_IN_PROGRESS$/
      end
    rescue Aws::Waiters::Errors::WaiterFailed => waiter_failed
      puts waiter_failed
    end
    stack
  end

  def create_stack_with_wait(cfn_client:,
                             stack_name:,
                             template_string:,
                             parameters:,
                             role_arn:)
    stack = cfn_resource(cfn_client).create_stack(
      stack_name: stack_name,
      template_body: template_string,
      parameters: parameters,
      capabilities: %w(CAPABILITY_NAMED_IAM),
      role_arn: role_arn
    )
    begin
      stack.wait_until(max_attempts:WAIT, delay:20) do |instance|
        !instance.stack_status.match /^.*_IN_PROGRESS$/
      end
    rescue Aws::Waiters::Errors::WaiterFailed => waiter_failed
      puts waiter_failed
    end
    stack
  end

  def self.initial_actions(cli_format_parameters_string)
    cli_format_parameters = JSON.parse cli_format_parameters_string
    cli_format_parameters['InitialActions']
  end

  def self.convert_parameters(cli_format_parameters_string)
    cli_format_parameters = JSON.parse cli_format_parameters_string
    cli_format_parameters['Parameters'].reduce([]) do |new_parameters, parameter|
      new_parameters << {
        parameter_key: parameter['ParameterKey'],
        parameter_value: parameter['ParameterValue'],
      }
      new_parameters
    end
  end
end