# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Share::Destroy < Service::BaseWithCurrentUser
  def execute(share:)
    Pundit.authorize current_user, share.ticket, :update?
    ensure_manageable!(share)

    serialized = serialize_share(share)

    # For destroy operations, we need to add the event to EventBuffer BEFORE destroying
    # because the record won't exist when TransactionDispatcher runs
    add_destroy_event_to_buffer(share)

    share.destroy!

    serialized
  end

  private

  def add_destroy_event_to_buffer(share)
    # Add destroy event to EventBuffer before destroying the record
    # IMPORTANT: Must include serialized data since record won't exist when notification runs
    EventBuffer.add('transaction', {
      object:     'Ticket::Share',
      type:       'delete',
      object_id:  share.id,  # Fixed: was 'id', should be 'object_id'
      user_id:    current_user.id,
      created_at: Time.zone.now,
      data:       serialize_share(share),  # Include data for notification to use
    })
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
      updated_at:       share.updated_at
    }
  end
end
