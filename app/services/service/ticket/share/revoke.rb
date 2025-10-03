# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Share::Revoke < Service::BaseWithCurrentUser
  def execute(share:)
    Pundit.authorize current_user, share.ticket, :update?
    ensure_manageable!(share)

    share.update!(status: 'revoked') unless share.status == 'revoked'
    share.reload

    # Send email notifications
    Service::Ticket::Share::EmailNotifier
      .new(current_user: current_user)
      .notify(share: share, action: :revoke)

    share
  end

  private

  def ensure_manageable!(share)
    return if share.shared_by_id == current_user.id || current_user.permissions?('admin')

    raise Exceptions::Forbidden, __('You can only revoke shares you created.')
  end
end
