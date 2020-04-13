require_relative 'iam_metadata'

class PolicyRenderer
  def render(service_to_statement, request_parameters=nil)
    iam_metadata = IamMetadata.new

    policy_string = "Statement:\n"
    service_to_statement.each do |service, statement|
      policy_string += "  - Effect: Allow\n"

      policy_string += "    Action:\n"
      statement.actions.each do |action|
        policy_string += "      - #{action}\n"
        if request_parameters && request_parameters[action]
          policy_string += "        # #{request_parameters[action]}\n"
        end
      end

      policy_string += "    Resource: '*'\n"
      if iam_metadata.resource_level_permissions?(service) == true
        found_non_wildcard_resource = false
        statement.resources.each do |resource|
          next if match_service_specific_wildcard(resource)
          policy_string += "# #{resource}\n"
          found_non_wildcard_resource = true
        end
        policy_string += "# #{service} supports resource level permissions but couldn't scrape any resource names\n" unless found_non_wildcard_resource
      else
        policy_string += "# #{service} has no resource level permissions or cant figure out if it does\n"
      end

      policy_string += "\n"
    end
    policy_string
  end

  def match_service_specific_wildcard(resource_name)
    resource_name.match /^[a-z]+:\*$/
  end
end
