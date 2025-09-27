# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddApprovalTicketStates < ActiveRecord::Migration[6.1]
  def up
    # Create new ticket state types for approval workflow
    Ticket::StateType.create_if_not_exists(
      id: 7,
      name: __('approved')
    )
    
    Ticket::StateType.create_if_not_exists(
      id: 8,
      name: __('rejected')
    )
    
    # Create ticket states for approved and rejected
    Ticket::State.create_if_not_exists(
      id: 7,
      name: __('approved'),
      state_type_id: Ticket::StateType.find_by(name: 'approved').id,
      ignore_escalation: true,
    )
    
    Ticket::State.create_if_not_exists(
      id: 8,
      name: __('rejected'),
      state_type_id: Ticket::StateType.find_by(name: 'rejected').id,
      ignore_escalation: true,
    )
  end
  
  def down
    # Remove the created states and state types
    Ticket::State.where(name: ['approved', 'rejected']).destroy_all
    Ticket::StateType.where(name: ['approved', 'rejected']).destroy_all
  end
end
