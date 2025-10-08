# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Approval::Destroy < Service::BaseWithCurrentUser
  def execute(approval:)
    Pundit.authorize current_user, approval.ticket, :update?
    ensure_requester_or_admin!(approval)

    serialized = serialize_approval(approval)
    
    # For destroy, we need to trigger notification BEFORE destroying
    # because Transaction system can't look up destroyed records
    trigger_destroy_notification(approval)
    
    approval.destroy!

    serialized
  end

  private

  def trigger_destroy_notification(approval)
    # Manually trigger notification before destroy
    notification = Transaction::ApprovalNotification.new(
      {
        object:     'Ticket::Approval',
        type:       'delete',
        object_id:  approval.id,
        user_id:    current_user.id,
        created_at: Time.zone.now,
      },
      { interface_handle: 'application_server' }
    )
    notification.perform
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
