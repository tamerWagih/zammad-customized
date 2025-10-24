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
    # Trigger ticket update (refreshes entire ticket in frontend)
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })

    # Trigger CC-specific update (optional - for granular updates)
    trigger_cc_subscription('create')
  end

  def trigger_update_subscriptions
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    trigger_cc_subscription('update')
  end

  def trigger_destroy_subscriptions
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    trigger_cc_subscription('destroy')
  end

  def trigger_cc_subscription(action)
    # Custom CC subscription event
    event_data = {
      cc: {
        id:          id,
        ticket_id:   ticket_id,
        user_id:     user_id,
        permissions: permissions,
        message:     message,
        user_name:   user_name,
        created_at:  created_at,
        updated_at:  updated_at
      }
    }

    Sessions.broadcast("TicketCc:#{action}", event_data)
  end
end

