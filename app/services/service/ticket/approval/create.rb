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

    ticket.approvals.create!(
      approver:  approver,
      requester: current_user,
      message:   message,
      priority:  normalized_priority,
      status:    'pending'
    )
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
