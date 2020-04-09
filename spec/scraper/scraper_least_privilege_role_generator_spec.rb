require 'cfn-least-privilege-role-generator/scraper/scraper_sufficient_role'
require 'cfn-least-privilege-role-generator/policy_renderer'

describe ScraperLeastPrivilegeRoleGenerator do

  context 'cfn template with lots of nec permissions', :c2 do
    it 'generates a role with all the actions' do
      create_parameters = [
        {
          parameter_key: 'HashKeyElementName',
          parameter_value: 'moocow'
        }
      ]

      role_and_policy = ScraperLeastPrivilegeRoleGenerator.new.create_stack_role(
        template_string: IO.read('spec/test_templates/DynamoDB_Table.template'),
        parameters: create_parameters
      )
      puts PolicyRenderer.new.render(role_and_policy)
    end
  end

  context 'cfn template with lots of nec permissions', :update do
    it 'generates a role with all the actions' do
      create_parameters = [
        {
          parameter_key: 'HashKeyElementName',
          parameter_value: 'moocow'
        }
      ]
      update_parameters = [
        {
          parameter_key: 'HashKeyElementName',
          parameter_value: 'moocow'
        },
        {
          parameter_key: 'ReadCapacityUnits',
          parameter_value: '10'
        }
      ]
      role_and_policy = ScraperLeastPrivilegeRoleGenerator.new.update_stack_role(
        create_template_string: IO.read('spec/test_templates/DynamoDB_Table.template'),
        create_parameters: create_parameters,
        update_template_string: IO.read('spec/test_templates/DynamoDB_Table.template'),
        update_parameters: update_parameters
      )
      puts PolicyRenderer.new.render(role_and_policy)
    end
  end

  context 'cfn template with lots of nec permissions2', :u2 do
    it 'generates a role with all the actions' do
      create_parameters = [
        {
          parameter_key: 'HashKeyElementName',
          parameter_value: 'moocow'
        }
      ]
      update_parameters = [
        {
          parameter_key: 'HashKeyElementName',
          parameter_value: 'moocow'
        },
        {
          parameter_key: 'ReadCapacityUnits',
          parameter_value: '10'
        }
      ]
      role_and_policy = ScraperLeastPrivilegeRoleGenerator.new.update_stack_role(
        create_template_string: IO.read('spec/test_templates/DynamoDB_Table.template'),
        create_parameters: create_parameters,
        update_template_string: IO.read('spec/test_templates/DynamoDB_Table2.template'),
        update_parameters: update_parameters
      )
      puts PolicyRenderer.new.render(role_and_policy)
    end
  end
end