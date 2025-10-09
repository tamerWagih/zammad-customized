# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Approval::Destroy < Service::BaseWithCurrentUser
  def execute(approval:)
    Pundit.authorize current_user, approval.ticket, :update?
    ensure_requester_or_admin!(approval)

    serialized = serialize_approval(approval)
    
    # For destroy operations, we need to add the event to EventBuffer BEFORE destroying
    # because the record won't exist when TransactionDispatcher runs
    add_destroy_event_to_buffer(approval)
    
    approval.destroy!

    serialized
  end

  private

  def add_destroy_event_to_buffer(approval)
    # Add destroy event to EventBuffer before destroying the record
    # IMPORTANT: Must include serialized data since record won't exist when notification runs
    Rails.logger.info "[APPROVAL_NOTIFICATION] ✅ DELETE event added to EventBuffer for approval ##{approval.id}"
    EventBuffer.add('transaction', {
      object:     'Ticket::Approval',
      type:       'delete',
      object_id:  approval.id,  # Fixed: was 'id', should be 'object_id'
      user_id:    current_user.id,
      created_at: Time.zone.now,
      data:       serialize_approval(approval),  # Include data for notification to use
    })
  end

  def ensure_requester_or_admin!(approval)
    return if approval.requester_id == current_user.id || current_user.permissions?('admin')

    raise Exceptions::Forbidden, __('You can only delete your own approval requests.')
  end

  def serialize_approval(approval)
    {
      id:           approval.id,
      ticket_id:    approval.ticket_id,
      approver_id:  approval.approver_id,
      approver:     approval.approver&.fullname,
      requester_id: approval.requester_id,
      requester:    approval.requester&.fullname,
      status:       approval.status,
      priority:     approval.priority,
      message:      approval.message,
      created_at:   approval.created_at,
      updated_at:   approval.updated_at
    }
  end
end
