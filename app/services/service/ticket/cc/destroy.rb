# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Cc::Destroy < Service::BaseWithCurrentUser
  def execute(cc:)
    Pundit.authorize current_user, cc.ticket, :update?
    ensure_manageable!(cc)

    serialized = serialize_cc(cc)

    # For destroy operations, we need to add the event to EventBuffer BEFORE destroying
    # because the record won't exist when TransactionDispatcher runs
    add_destroy_event_to_buffer(cc)

    cc.destroy!

    serialized
  end

  private

  def add_destroy_event_to_buffer(cc)
    # Add destroy event to EventBuffer before destroying the record
    # IMPORTANT: Must include serialized data since record won't exist when notification runs
    EventBuffer.add('transaction', {
      object:     'Ticket::Cc',
      type:       'delete',
      object_id:  cc.id,
      user_id:    current_user.id,
      created_at: Time.zone.now,
      data:       serialize_cc(cc),  # Include data for notification to use
    })
  end

  def ensure_manageable!(cc)
    return if cc.created_by_id == current_user.id || current_user.permissions?('admin')

    raise Exceptions::Forbidden, __('You can only delete CC records you created.')
  end

  def serialize_cc(cc)
    {
      id:               cc.id,
      ticket_id:        cc.ticket_id,
      user_id:          cc.user_id,
      user_name:        cc.user&.fullname,
      permissions:      cc.permissions,
      message:          cc.message,
      created_by_id:    cc.created_by_id,
      created_by_name:  cc.created_by&.fullname,
      created_at:       cc.created_at,
      updated_at:       cc.updated_at
    }
  end
end

