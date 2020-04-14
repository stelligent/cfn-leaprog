require_relative '../cloudformation'
require_relative '../logging'
require_relative 'admin_role'

##
# This class is repsonsible for calling CreateStack, UpdateStack and DeleteStack
# against CloudFormation templates with a unique IAM role in order to generate events...
# the unique IAM role is later used to put these events in order
#
# This object has nothing to do with catching, parsing or processing those events,
# it's a "simple" set of calls to CloudFormation with the IAM role to converge things
#
class CloudFormationConvergerWithRole
  include Logging
  include CloudFormation

  def initialize(iam_client, cfn_client)
    @iam_client = iam_client
    @cfn_client = cfn_client
  end

  def converge_and_update_template(create_template_string:, create_parameters:, update_template_string:, update_parameters:)
    role_name = new_role_name
    admin_role = AdminRole.new
    admin_role_arn = admin_role.create(iam_client: @iam_client, role_name: role_name)

    logger.info('Converging stack...')
    logger.debug("With iam role: #{admin_role_arn}")

    stack = create_stack_with_wait(
      cfn_client: @cfn_client,
      stack_name: role_name,
      template_string: create_template_string,
      parameters: create_parameters,
      role_arn: admin_role_arn
    )

    logger.info('Updating stack...')

    stack = update_stack_and_wait(
      cfn_client: @cfn_client,
      stack_name: stack.stack_id,
      template_string: update_template_string,
      parameters: update_parameters,
      role_arn: admin_role_arn
    )

    logger.info('Deleting stack...')

    delete_stack_and_wait @cfn_client, stack

    admin_role.delete(iam_client: @iam_client, role_name: role_name)
    admin_role_arn
  end

  def converge_template(template_string:, parameters:)
    role_name = new_role_name
    admin_role = AdminRole.new
    admin_role_arn = admin_role.create(iam_client: @iam_client, role_name: role_name)

    logger.info('Converging stack...')
    logger.debug("With iam role: #{admin_role_arn}")

    stack = create_stack_with_wait(
      cfn_client: @cfn_client,
      stack_name: role_name,
      template_string: template_string,
      parameters: parameters,
      role_arn: admin_role_arn
    )

    logger.info('Deleting stack...')

    delete_stack_and_wait @cfn_client, stack

    admin_role.delete(iam_client: @iam_client, role_name: role_name)
    admin_role_arn
  end

  def self.iam_role_arn(account_id, role_id)
    "arn:aws:iam::#{account_id}:role/cfn-leaprog-#{role_id}"
  end

  private

  def new_role_name
    "cfn-leaprog-#{Time.now.to_i}"
  end
end
