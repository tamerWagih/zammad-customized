# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class ConvertApprovalStatesToTags < ActiveRecord::Migration[7.2]
  def up
    # Get IDs for 'approved' (7) and 'rejected' (8) states
    approved_state_id = 7
    rejected_state_id = 8

    # Convert existing tickets with 'approved' state to 'approved' tag
    Ticket.where(state_id: approved_state_id).find_each do |ticket|
      ticket.tag_add('approved', 1) # Using user ID 1 (system user) for migration
    end

    # Convert existing tickets with 'rejected' state to 'rejected' tag
    Ticket.where(state_id: rejected_state_id).find_each do |ticket|
      ticket.tag_add('rejected', 1) # Using user ID 1 (system user) for migration
    end

    # Update overviews to use tag-based filtering instead of state-based
    # Overview 100: 'Approved Tickets'
    Overview.where(id: 100, name: 'Approved Tickets').update_all(
      condition: { 'ticket.tags' => { 'operator' => 'contains one', 'value' => 'approved' } }.to_json
    )

    # Overview 101: 'Rejected Tickets'
    Overview.where(id: 101, name: 'Rejected Tickets').update_all(
      condition: { 'ticket.tags' => { 'operator' => 'contains one', 'value' => 'rejected' } }.to_json
    )

    # Remove the 'approved' and 'rejected' ticket states
    Ticket::State.where(name: ['approved', 'rejected']).destroy_all
  end

  def down
    # Recreate the approval/rejection states
    Ticket::StateType.find_or_create_by(name: 'closed') do |type|
      type.created_by_id = 1
      type.updated_by_id = 1
    end
    
    state_type = Ticket::StateType.find_by(name: 'closed')
    
    Ticket::State.find_or_create_by(name: 'approved') do |state|
      state.state_type_id = state_type.id
      state.ignore_escalation = true
      state.created_by_id = 1
      state.updated_by_id = 1
    end
    
    Ticket::State.find_or_create_by(name: 'rejected') do |state|
      state.state_type_id = state_type.id
      state.ignore_escalation = true
      state.created_by_id = 1
      state.updated_by_id = 1
    end

    # Revert overviews to state-based filtering
    approved_state = Ticket::State.find_by(name: 'approved')
    rejected_state = Ticket::State.find_by(name: 'rejected')

    if approved_state
      Overview.where(id: 100, name: 'Approved Tickets').update_all(
        condition: { 'ticket.state_id' => { 'operator' => 'is', 'value' => [approved_state.id] } }.to_json
      )
    end

    if rejected_state
      Overview.where(id: 101, name: 'Rejected Tickets').update_all(
        condition: { 'ticket.state_id' => { 'operator' => 'is', 'value' => [rejected_state.id] } }.to_json
      )
    end

    # Remove 'approved' and 'rejected' tags from all tickets
    Ticket.find_each do |ticket|
      ticket.tag_remove('approved', 1) if ticket.tag_list.include?('approved')
      ticket.tag_remove('rejected', 1) if ticket.tag_list.include?('rejected')
    end
  end
end
