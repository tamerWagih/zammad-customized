# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Trigger GraphQL subscriptions on ticket approval changes.
module Ticket::Approval::TriggersSubscriptions
  extend ActiveSupport::Concern

  included do
    after_create_commit  :trigger_create_subscriptions
    after_update_commit  :trigger_update_subscriptions
    after_destroy_commit :trigger_destroy_subscriptions
  end

  private

  def trigger_create_subscriptions
    # Trigger ticket update since approval affects ticket state
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger approval-specific update
    trigger_approval_subscription('create')
  end

  def trigger_update_subscriptions
    # Trigger ticket update since approval affects ticket state
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger approval-specific update
    trigger_approval_subscription('update')
  end

  def trigger_destroy_subscriptions
    # Trigger ticket update since approval affects ticket state
    Gql::Subscriptions::TicketUpdates.trigger(ticket, arguments: { ticket_id: Gql::ZammadSchema.id_from_object(ticket) })
    
    # Trigger approval-specific update
    trigger_approval_subscription('destroy')
  end

  def trigger_approval_subscription(action)
    # Custom approval subscription event
    # This will trigger frontend listeners for TicketApproval events
    event_data = { 
      approval: {
        id: id,
        ticket_id: ticket_id,
        status: status,
        message: message,
        priority: priority,
        approver: approver&.fullname,
        requester: requester&.fullname,
        created_at: created_at,
        updated_at: updated_at
      }
    }
    
    Rails.logger.info "[APPROVAL_WEBSOCKET] Broadcasting TicketApproval:#{action} for approval ##{id} (ticket ##{ticket_id})"
    Rails.logger.info "[APPROVAL_WEBSOCKET] Event data: #{event_data.inspect}"
    Sessions.broadcast("TicketApproval:#{action}", event_data)
    Rails.logger.info "[APPROVAL_WEBSOCKET] Broadcast completed for TicketApproval:#{action}"
  end
end
