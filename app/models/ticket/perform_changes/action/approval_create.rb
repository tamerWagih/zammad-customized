# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Ticket::PerformChanges::Action::ApprovalCreate < Ticket::PerformChanges::Action

  def self.phase
    :after_save
  end

  def execute(...)
    create_approval(execution_data)
  end

  private

  def create_approval(approval_data)
    # Extract approval parameters
    approver_id = approval_data['approver_id'] || approval_data[:approver_id]
    priority = approval_data['priority'] || approval_data[:priority] || 'normal'
    
    # Support both user_id and login formats
    if approver_id.is_a?(String) && approver_id !~ /^\d+$/
      # It's a login or email, find the user
      approver = User.find_by(login: approver_id) || User.find_by(email: approver_id)
      approver_id = approver&.id
    end
    
    return if approver_id.blank?

    # Get the requester (current user or ticket customer)
    requester_id = user_id || record.customer_id

    # Create the approval request
    approval = Ticket::Approval.new(
      ticket_id:     record.id,
      approver_id:   approver_id.to_i,
      requester_id:  requester_id,
      priority:      priority,
      status:        'pending',
      created_by_id: user_id || 1,
      updated_by_id: user_id || 1,
    )

    approval.save!

    Rails.logger.info { "Created approval request for ticket #{record.id} with approver #{approver_id} via trigger" }
  end
end

