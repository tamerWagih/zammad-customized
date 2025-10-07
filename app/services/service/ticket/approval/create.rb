# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Approval::Create < Service::BaseWithCurrentUser
  VALID_PRIORITIES = %w[low normal high urgent].freeze

  def execute(ticket:, approver_id:, message: nil, priority: nil)
    Pundit.authorize current_user, ticket, :update?

    approver = User.find(approver_id)
    normalized_priority = normalize_priority(priority)

    if ticket.approvals.pending.exists?(approver_id: approver.id)
      raise Exceptions::UnprocessableEntity,
            __('An approval request has already been sent to %s. Please update the existing request.') % approver.fullname
    end

    approval = ticket.approvals.create!(
      approver:  approver,
      requester: current_user,
      message:   message,
      priority:  normalized_priority,
      status:    'pending'
    )

    # NOTE: Auto-share removed!
    # Approvers now get access via TicketPolicy#approval_access?
    # This prevents giving access to the entire group and maintains security.
    # Only the specific approver gets full access to the ticket.

    # Send email notifications
    Service::Ticket::Approval::EmailNotifier
      .new(current_user: current_user)
      .notify(approval: approval, action: :create)

    approval
  end

  private

  def normalize_priority(value)
    priority = value.to_s.presence || 'normal'
    unless VALID_PRIORITIES.include?(priority)
      raise Exceptions::UnprocessableEntity,
            __('Approval priority must be one of: %s.') % VALID_PRIORITIES.join(', ')
    end
    priority
  end
end
