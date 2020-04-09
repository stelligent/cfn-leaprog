require 'json'

module CloudFormationStackEvents
  def describe_stack_events(cfn_client, stack_id)
    token = nil
    done = false
    events = []
    until done
      describe_stack_events_response = cfn_client.describe_stack_events(
        stack_name: stack_id,
        next_token: token
      )
      events += describe_stack_events_response.stack_events
      token = describe_stack_events_response.next_token
      done = true unless token
    end
    events
  end

  def update_events(cfn_client, stack_id)
    update_only_events = []
    # this could be more efficient i guess but the flightiness of the events showing up...
    stack_events(cfn_client, stack_id).each do |event|
      update_only_events << event
      if event.resource_status_reason == 'User Initiated'
        break
      end
    end
    update_only_events
  end

  def stack_events(cfn_client, stack_id)
    # the stack events seem to lag quite a bit, so query them a few times until stable
    # with a wait in between
    stable = false
    prior_events = nil
    until stable do
      events = describe_stack_events cfn_client, stack_id
      if prior_events == events
        stable = true
      else
        prior_events = events
        sleep 20
      end
    end
    events
  end
end