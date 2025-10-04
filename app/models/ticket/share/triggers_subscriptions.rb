# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Trigger GraphQL subscriptions on ticket share changes.
module Ticket::Share::TriggersSubscriptions
  extend ActiveSupport::Concern

  included do
    after_create_commit  :trigger_create_subscriptions
    after_update_commit  :trigger_update_subscriptions
    after_destroy_commit :trigger_destroy_subscriptions
  end

  private

  def trigger_create_subscriptions
    # Trigger ticket update since share affects ticket permissions
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger share-specific update
    trigger_share_subscription('create')
  end

  def trigger_update_subscriptions
    # Trigger ticket update since share affects ticket permissions
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger share-specific update
    trigger_share_subscription('update')
  end

  def trigger_destroy_subscriptions
    # Trigger ticket update since share affects ticket permissions
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger share-specific update
    trigger_share_subscription('destroy')
  end

  def trigger_share_subscription(action)
    # Custom share subscription event
    # This will trigger frontend listeners for TicketShare events
    event_data = {
      share: {
        id: id,
        ticket_id: ticket_id,
        group_id: group_id,
        group: group&.fullname || group&.name,
        permissions: permissions,
        message: message,
        status: status,
        created_at: created_at,
        expires_at: expires_at,
        updated_at: updated_at
      }
    }
    
    Sessions.broadcast("TicketShare:#{action}", event_data)
  end
end


