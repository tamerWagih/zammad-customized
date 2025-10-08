# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Trigger Transaction notifications for approval actions
module Ticket::Approval::TriggersNotifications
  extend ActiveSupport::Concern

  included do
    after_create_commit  :trigger_create_notification
    after_update_commit  :trigger_update_notification
    after_destroy_commit :trigger_destroy_notification
  end

  private

  def trigger_create_notification
    user_id = UserInfo.current_user_id || 1
    Rails.logger.info "[APPROVAL_NOTIFICATION] ✅ CREATE triggered for approval ##{id} by user ##{user_id}"
    EventBuffer.add('transaction', {
      object:     'Ticket::Approval',
      type:       'create',
      object_id:  id,
      user_id:    user_id,
      created_at: Time.zone.now,
    })
    Rails.logger.info "[APPROVAL_NOTIFICATION] 📨 Event added to EventBuffer: Ticket::Approval ##{id} (create)"
  end

  def trigger_update_notification
    user_id = UserInfo.current_user_id || 1
    
    # Determine specific action type based on status changes
    type = if saved_change_to_status?
      case status
      when 'approved'
        'approve'
      when 'rejected'
        'reject'
      else
        'update'
      end
    else
      'update'
    end

    Rails.logger.info "[APPROVAL_NOTIFICATION] ✅ #{type.upcase} triggered for approval ##{id} by user ##{user_id}"
    EventBuffer.add('transaction', {
      object:     'Ticket::Approval',
      type:       type,
      object_id:  id,
      changes:    saved_changes,
      user_id:    user_id,
      created_at: Time.zone.now,
    })
    Rails.logger.info "[APPROVAL_NOTIFICATION] 📨 Event added to EventBuffer: Ticket::Approval ##{id} (#{type})"
  end

  def trigger_destroy_notification
    # Note: We can't add this to EventBuffer because the record will be destroyed
    # and the Transaction backend won't be able to look it up
    # The Transaction system runs AFTER the transaction commits
    # For destroy, we handle notifications in the service layer before destroying
    # This is acceptable because destroy is a deliberate action, not a side effect
  end
end

