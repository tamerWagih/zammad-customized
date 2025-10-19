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
    
    # Log the ticket context (for debugging)
    Rails.logger.info { "Creating approval for ticket ##{record.id} (#{record.title}) via trigger" }
    
    # Support both user_id and login/email formats
    if approver_id.is_a?(String)
      if approver_id =~ /^\d+$/
        # It's a numeric string, convert to integer
        approver_id = approver_id.to_i
      else
        # It's a login or email, find the user
        approver = User.find_by(login: approver_id) || User.find_by(email: approver_id)
        if approver.nil?
          Rails.logger.warn "Approval trigger: Approver not found with identifier '#{approver_id}' for ticket #{record.id}"
          return
        end
        approver_id = approver.id
      end
    end
    
    if approver_id.blank?
      Rails.logger.warn "Approval trigger: No approver_id provided for ticket #{record.id}"
      return
    end

    # Verify the approver exists
    unless User.exists?(approver_id)
      Rails.logger.warn "Approval trigger: Approver with ID #{approver_id} does not exist for ticket #{record.id}"
      return
    end

    # Get the requester (current user or ticket customer)
    requester_id = user_id || record.customer_id

    # Validate priority
    priority = 'normal' unless Ticket::Approval::PRIORITIES.include?(priority)

    # Create the approval request
    approval = Ticket::Approval.new(
      ticket_id:     record.id,
      approver_id:   approver_id,
      requester_id:  requester_id,
      priority:      priority,
      status:        'pending',
      created_by_id: user_id || 1,
      updated_by_id: user_id || 1,
    )

    if approval.save
      Rails.logger.info { "Created approval request ##{approval.id} for ticket #{record.id} with approver #{approver_id} (priority: #{priority}) via trigger" }
    else
      Rails.logger.error { "Failed to create approval request for ticket #{record.id}: #{approval.errors.full_messages.join(', ')}" }
    end
  end
end

