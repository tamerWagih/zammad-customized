# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Ticket::CC::TriggersNotifications
  extend ActiveSupport::Concern
  
  included do
    after_create :trigger_create_notification
    after_destroy :trigger_destroy_notification
  end
  
  private
  
  def trigger_create_notification
    OnlineNotification.add(
      type:          'You were CC\'d on a ticket',
      object:        'Ticket',
      o_id:          ticket_id,
      seen:          false,
      user_id:       user_id,
      created_by_id: created_by_id || 1,
    )
  end
  
  def trigger_destroy_notification
    OnlineNotification.remove_by_type('Ticket', ticket_id, 'You were CC\'d on a ticket', user)
  end
end

