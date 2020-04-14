
class Policy
  STACK_NAME_STEM = 'cfn-leaprog'

  class Statement
    attr_accessor :actions, :resources

    def initialize
      @actions = []
      @resources = []
    end

    def self.construct(actions, resources)
      statement = Statement.new
      statement.actions = actions
      statement.resources = resources
      statement
    end

    def ==(other)
      Set.new(@actions) == Set.new(other.actions) &&
      Set.new(@resources) == Set.new(other.resources)
    end
  end

  def reorganize_statements_by_service(actions, candidate_resources, request_parameters=nil)
    service_to_statement = break_up_statement_actions_into_service_specific_statements(
      actions
    )

    associate_resources_with_service_specific_statements(
      service_to_statement,
      candidate_resources
    )

    [service_to_statement, request_parameters]
  end

  private

  def associate_resources_with_service_specific_statements(service_to_statement, candidate_resources)
    filter_resources(candidate_resources).each do |candidate_resource|
      if match_service_specific_wildcard(candidate_resource)
        service = service_name_prefix_from_resource_specific_wildcard(candidate_resource)
      else
        service = service_name_prefix_from_resource(candidate_resource)
      end

      statement = service_to_statement[service]
      statement.resources << candidate_resource
    end
  end

  def break_up_statement_actions_into_service_specific_statements(actions)
    service_to_statement = {}
    actions.each do |action|
      service_name = service_name_prefix_from_action(action)
      if service_to_statement[service_name]
        statement = service_to_statement[service_name]
        statement.actions << action
      else
        statement = Statement.new
        statement.actions << action
        service_to_statement[service_name] = statement
      end
    end
    service_to_statement
  end

  def match_service_specific_wildcard(resource_name)
    resource_name.match /^[a-z]+:\*$/
  end

  ##
  # remove any cfn suffixes and remove the timestamp from the stack name
  # for the iteration
  def canonical_resource_name(resource_name)
    if resource_name.include? '-'
       without_random_suffix = "#{resource_name.split('-')[0..-2].join('-')}-*"
       without_random_suffix.gsub(/#{STACK_NAME_STEM}\d+/, "#{STACK_NAME_STEM}*")
    else
      resource_name
    end
  end

  def filter_resources(resources)
    Set.new(
      resources.to_a.select do |resource|
        resource.start_with?('arn')
      end.map do |resource_name|
        canonical_resource_name(resource_name)
      end
    )
  end

  def service_name_prefix_from_action(action)
    action.split(':')[0]
  end
  alias_method :service_name_prefix_from_resource_specific_wildcard, :service_name_prefix_from_action

  def service_name_prefix_from_resource(resource_arn)
    resource_arn.split(':')[2]
  end
end
