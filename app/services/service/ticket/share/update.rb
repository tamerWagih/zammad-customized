# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Share::Update < Service::BaseWithCurrentUser
  VALID_PERMISSIONS = Service::Ticket::Share::Create::VALID_PERMISSIONS

  def execute(share:, attributes: {})
    Pundit.authorize current_user, share.ticket, :update?
    ensure_manageable!(share)

    updates = {}

    if attributes.key?(:permissions)
      updates[:permissions] = normalize_permissions(attributes[:permissions])
    end

    if attributes.key?(:message)
      updates[:message] = attributes[:message]
    end

    if attributes.key?(:expires_at)
      updates[:expires_at] = normalize_expires_at(attributes[:expires_at])
    end

    share.update!(updates) if updates.any?
    share.reload
  end

  private

  def ensure_manageable!(share)
    return if share.shared_by_id == current_user.id || current_user.permissions?('admin')

    raise Exceptions::Forbidden, __('You can only update shares you created.')
  end

  def normalize_permissions(raw_permissions)
    permissions = Array(raw_permissions).map(&:to_s).reject(&:blank?).uniq
    permissions = ['read'] if permissions.empty?

    invalid = permissions - VALID_PERMISSIONS
    if invalid.any?
      raise Exceptions::UnprocessableEntity,
            __('Share permissions contain unsupported values: %s.') % invalid.join(', ')
    end

    permissions
  end

  def normalize_expires_at(value)
    value.presence
  end
end
