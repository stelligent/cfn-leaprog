require 'set'
require 'logger'
require 'aws-sdk-cloudformation'
require_relative '../policy'
require_relative '../cloudformation'
require_relative 'iam_role'
require_relative 'clients'
require_relative 'cfn_stack_events_scraper'
require_relative 'cloudformation_stack_events'

class ScraperLeastPrivilegeRoleGenerator
  include Clients
  include CloudFormation
  include CloudFormationStackEvents

  WAIT = 250

  def initialize
    @role_name = 'cfn-least-privilege-role-generator'
    @failed_stack_ids = []
    @events_scraper = CfnStackEventsScraper.new
  end

  def update_stack_role(create_template_string:,
                        create_parameters:,
                        update_template_string:,
                        update_parameters:)
    service_to_statements_hash = create_stack_role(
      template_string: create_template_string,
      parameters: create_parameters
    )
    # everything should be deleted at this point...
    # and the role should be fully populated for create and delete stack
    # we could try to keep stuff but i think it's messier
    # than just doing it e2e again?

    role_and_policy = nil

    get_role_response = iam_client.get_role role_name: @role_name
    role_hash = get_role_response.to_h[:role]

    baseline_actions = actions(service_to_statements_hash)
    baseline_resources = resources(service_to_statements_hash)

    sufficient_actions = Set.new(baseline_actions.to_a)
    candidate_resources = Set.new(baseline_resources.to_a)

    # create it one more time to baseline
    stack = create_stack_with_wait(
      cfn_client: cfn_client,
      stack_name: "cfn-least-privilege-role-generator#{Time.now.to_i}",
      template_string: create_template_string,
      parameters: create_parameters,
      role_arn: role_hash[:arn]
    )
    @failed_stack_ids << stack.stack_id

    while true
      stack = update_stack_and_wait(
        cfn_client: cfn_client,
        stack_name: stack.stack_id,
        template_string: update_template_string,
        parameters: update_parameters,
        role_arn: role_hash[:arn]
      )
      @failed_stack_ids << stack.stack_id

      actions_to_add, resources_to_add = @events_scraper.missing_actions_and_resources(
        events_to_scrape: update_events(cfn_client, stack.stack_id)
      )

      candidate_resources += Set.new(resources_to_add)
      if actions_to_add == []
        break
      else
        sufficient_actions += Set.new(actions_to_add)
      end

      iam_role = IamRole.new
      role_and_policy = iam_role.converge(
        iam_client: iam_client,
        role_name: @role_name,
        actions: sufficient_actions.to_a
      )
    end

    delete_stack_and_wait cfn_client, stack

    cleanup

    Policy.new.reorganize_statements_by_service(
      role_and_policy[:policy]['Statement']['Action'],
      candidate_resources
    )
  end

  ##
  # Generate an IAM role with the minimal actions to CreateStack on supplied template
  #
  def create_stack_role(template_string:,
                        parameters:,
                        initial_actions: nil)
    logger.info('Starting..')
    logger.debug(template_string)
    logger.debug(parameters)

    iam_role = IamRole.new
    role_and_policy = iam_role.reset(
      iam_client: iam_client,
      role_name: @role_name
    )
    sleep 5

    logger.info('cfn-least-privilege-role-generator is reset')

    sufficient_actions = initial_actions ? Set.new(initial_actions): Set.new
    candidate_resources = Set.new
    while true
      unless sufficient_actions.empty?
        logger.info("Converging cfn-least-privilege-role-generator with actions: #{sufficient_actions}")

        role_and_policy = iam_role.converge(
          iam_client: iam_client,
          role_name: @role_name,
          actions: sufficient_actions.to_a
        )
      end

      logger.info('Converging stack...')
      logger.debug("With iam role: #{role_and_policy}")

      stack = create_stack_with_wait(
        cfn_client: cfn_client,
        stack_name: "cfn-least-privilege-role-generator#{Time.now.to_i}",
        template_string: template_string,
        parameters: parameters,
        role_arn: role_and_policy[:role][:arn]
      )

      stack_id = stack.stack_id
      @failed_stack_ids << stack_id

      # try to delete it and fail so that we can suck up the missing Delete* actions
      logger.info('Deleting stack...')

      delete_stack_and_wait cfn_client, stack

      actions_to_add, resources_to_add = @events_scraper.missing_actions_and_resources(
        events_to_scrape: stack_events(cfn_client, stack_id)
      )

      logger.info("Missing actions: #{actions_to_add}")

      candidate_resources += Set.new(resources_to_add)
      if actions_to_add == []
        break
      else
        actions_to_add_set = Set.new(actions_to_add)
        leftovers = actions_to_add_set - sufficient_actions
        if leftovers.empty?
          sufficient_actions += Set.new(leftovers.map { |leftover| "#{service_name(leftover)}:*"})
        else
          sufficient_actions += Set.new(actions_to_add)
        end
      end
    end

    cleanup

    Policy.new.reorganize_statements_by_service(
      role_and_policy[:policy]['Statement']['Action'],
      candidate_resources
    )
  end

  private

  def self.initial_actions(cli_format_parameters_string)
    cli_format_parameters = JSON.parse cli_format_parameters_string
    cli_format_parameters['InitialActions']
  end


  # def action_that_represents_multiple_actions?(actions)
  #
  # end
  #
  def cleanup
    @failed_stack_ids.each do |stack_id|
      begin
        cfn_client.delete_stack(
          stack_name: stack_id
        )
      rescue
      end
    end

    @failed_stack_ids.each do |stack_id|
      begin
        stack = cfn_resource(cfn_client).stack(stack_id)
        stack.wait_until(max_attempts:WAIT, delay:20) do |instance|
          !instance.stack_status.match /^.*_IN_PROGRESS$/
        end
      rescue Aws::Waiters::Errors::WaiterFailed => waiter_failed
        puts waiter_failed
      end
    end
    @failed_stack_ids = []
  end

  def actions(service_to_statements_hash)
    action_set = Set.new
    service_to_statements_hash.values.each do |statement|
      action_set += statement.actions
    end
    action_set
  end

  def resources(service_to_statements_hash)
    resources_set = Set.new
    service_to_statements_hash.values.each do |statement|
      resources_set += statement.resources
    end
    resources_set
  end

  def service_name(api_call)
    api_call.split(':')[0]
  end

  def logger
    Logger.new(STDOUT)
  end
end
