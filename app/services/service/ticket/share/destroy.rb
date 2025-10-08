# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Share::Destroy < Service::BaseWithCurrentUser
  def execute(share:)
    Pundit.authorize current_user, share.ticket, :update?
    ensure_manageable!(share)

    serialized = serialize_share(share)

    # For destroy, we need to trigger notification BEFORE destroying
    # because Transaction system can't look up destroyed records
    trigger_destroy_notification(share)

    share.destroy!

    serialized
  end

  private

  def trigger_destroy_notification(share)
    # Manually trigger notification before destroy
    notification = Transaction::ShareNotification.new(
      {
        object:     'Ticket::Share',
        type:       'delete',
        object_id:  share.id,
        user_id:    current_user.id,
        created_at: Time.zone.now,
      },
      { interface_handle: 'application_server' }
    )
    notification.perform
  end

  def ensure_manageable!(share)
    return if share.shared_by_id == current_user.id || current_user.permissions?('admin')

    raise Exceptions::Forbidden, __('You can only delete shares you created.')
  end

  def serialize_share(share)
    {
      id:               share.id,
      ticket_id:        share.ticket_id,
      group_id:         share.group_id,
      group_name:       share.group_name,
      shared_by_id:     share.shared_by_id,
      shared_by_name:   share.shared_by&.fullname,
      permissions:      share.permissions,
      message:          share.message,
      status:           share.status,
      created_at:       share.created_at,
      updated_at:       share.updated_at,
      expires_at:       share.expires_at
    }
  end
end
