# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Cc::Update < Service::BaseWithCurrentUser
  def execute(cc:, attributes: {})
    Pundit.authorize current_user, cc.ticket, :update?
    ensure_manageable!(cc)

    updates = {}

    if attributes.key?(:message)
      updates[:message] = attributes[:message]
    end

    if attributes.key?(:permissions)
      updates[:permissions] = Array(attributes[:permissions])
    end

    cc.update!(updates) if updates.any?
    cc.reload

    # Transaction::CcNotification will be triggered automatically via callbacks

    cc
  end

  private

  def ensure_manageable!(cc)
    return if cc.created_by_id == current_user.id || current_user.permissions?('admin')

    raise Exceptions::Forbidden, __('You can only update CC records you created.')
  end
end

