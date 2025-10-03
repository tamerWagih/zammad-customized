// Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

import { useSessionStore } from '#shared/stores/session.ts'

import type { TicketById, TicketView } from '../types.ts'

export const getTicketView = (ticket: TicketById) => {
  const session = useSessionStore()

  // Check if user has read-only access via share (has read access but not edit access)
  const isReadOnlyShareAccess = ticket.policy.agentReadAccess && !(ticket.policy as any).agentUpdateAccess && ticket.policy.update

  // Ticket is editable if user has update permission AND is not read-only share access
  const isTicketEditable = ticket.policy.update && !isReadOnlyShareAccess

  const isTicketCustomer =
    session.hasPermission('ticket.customer') && !ticket.policy.agentReadAccess

  const isTicketAgent = ticket.policy.agentReadAccess

  const ticketView: TicketView = isTicketAgent ? 'agent' : 'customer'

  return {
    isTicketAgent,
    isTicketCustomer,
    isTicketEditable,
    isReadOnlyShareAccess,
    ticketView,
  }
}
