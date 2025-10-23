# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Trigger GraphQL subscriptions on ticket CC changes.
module Ticket::Cc::TriggersSubscriptions
  extend ActiveSupport::Concern

  included do
    after_create_commit  :trigger_create_subscriptions
    after_update_commit  :trigger_update_subscriptions
    after_destroy_commit :trigger_destroy_subscriptions
  end

  private

  def trigger_create_subscriptions
    # Trigger ticket update since CC affects ticket state
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger CC-specific update
    trigger_cc_subscription('create')
  end

  def trigger_update_subscriptions
    # Trigger ticket update since CC affects ticket state
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger CC-specific update
    trigger_cc_subscription('update')
  end

  def trigger_destroy_subscriptions
    # Trigger ticket update since CC affects ticket state
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger CC-specific update
    trigger_cc_subscription('destroy')
  end

  def trigger_cc_subscription(action)
    # Custom CC subscription event
    # This will trigger frontend listeners for TicketCc events
    event_data = { 
      cc: {
        id: id,
        ticket_id: ticket_id,
        user_id: user_id,
        permissions: permissions,
        message: message,
        user_name: user_name,
        created_at: created_at,
        updated_at: updated_at
      }
    }
    
    Rails.logger.info "[CC_WEBSOCKET] Broadcasting TicketCc:#{action} for CC ##{id} (ticket ##{ticket_id})"
    Rails.logger.info "[CC_WEBSOCKET] Event data: #{event_data.inspect}"
    Sessions.broadcast("TicketCc:#{action}", event_data)
    Rails.logger.info "[CC_WEBSOCKET] Broadcast completed for TicketCc:#{action}"
  end
end
