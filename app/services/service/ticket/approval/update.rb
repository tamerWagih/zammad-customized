# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Approval::Update < Service::BaseWithCurrentUser
  VALID_PRIORITIES = Service::Ticket::Approval::Create::VALID_PRIORITIES

  def execute(approval:, attributes: {})
    Pundit.authorize current_user, approval.ticket, :update?
    ensure_requester_or_admin!(approval)

    updates = {}
    updates[:message] = attributes[:message] if attributes.key?(:message)

    if attributes.key?(:priority)
      updates[:priority] = normalize_priority(attributes[:priority])
    end

    approval.update!(updates) if updates.any?
    approval.reload

    # Transaction::ApprovalNotification will be triggered automatically via callbacks

    approval
  end

  private

  def ensure_requester_or_admin!(approval)
    return if approval.requester_id == current_user.id || current_user.permissions?('admin')

    raise Exceptions::Forbidden, __('You can only edit your own approval requests.')
  end

  def normalize_priority(value)
    priority = value.to_s.presence || 'normal'
    unless VALID_PRIORITIES.include?(priority)
      raise Exceptions::UnprocessableEntity,
            __('Approval priority must be one of: %s.') % VALID_PRIORITIES.join(', ')
    end
    priority
  end
end
