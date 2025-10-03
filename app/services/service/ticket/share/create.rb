# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Share::Create < Service::BaseWithCurrentUser
  VALID_PERMISSIONS = %w[read comment edit].freeze

  def execute(ticket:, shared_with_id:, permissions:, message: nil, expires_at: nil)
    Pundit.authorize current_user, ticket, :update?

    shared_user = User.find(shared_with_id)
    normalized_permissions = normalize_permissions(permissions)

    if ticket.shares.active_current.exists?(shared_with_id: shared_user.id)
      raise Exceptions::UnprocessableEntity,
            __('This ticket is already shared with %s. Please update the existing share instead.') % shared_user.fullname
    end

    share = ticket.shares.create!(
      shared_with: shared_user,
      shared_by:   current_user,
      permissions: normalized_permissions,
      message:     message,
      expires_at:  normalize_expires_at(expires_at),
      status:      'active'
    )

    # Send email notifications
    Service::Ticket::Share::EmailNotifier
      .new(current_user: current_user)
      .notify(share: share, action: :create)

    share
  end

  private

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
