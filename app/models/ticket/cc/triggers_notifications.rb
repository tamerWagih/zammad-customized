# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Ticket::Cc::TriggersNotifications
  extend ActiveSupport::Concern

  included do
    after_create :trigger_create_notification
    after_destroy :trigger_destroy_notification
  end

  private

  def trigger_create_notification
    TransactionDispatcher.commit(
      'Ticket::Cc' => {
        ticket_id: ticket_id,
        cc_id: id,
        action: 'create',
        user_id: user_id,
        created_by_id: created_by_id,
        message: message,
        permissions: permissions
      }
    )
  end

  def trigger_destroy_notification
    TransactionDispatcher.commit(
      'Ticket::Cc' => {
        ticket_id: ticket_id,
        cc_id: id,
        action: 'destroy',
        user_id: user_id,
        created_by_id: created_by_id
      }
    )
  end
end
