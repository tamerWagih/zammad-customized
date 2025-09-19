// Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

import { TicketSidebarScreenType, type TicketSidebarContext } from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarApprovalSharing from '../TicketSidebarApprovalSharing/TicketSidebarApprovalSharing.vue'

import type { TicketSidebarPlugin } from './types.ts'

export default <TicketSidebarPlugin>{
  title: __('Approval & Sharing'),
  component: TicketSidebarApprovalSharing,
  permissions: ['ticket.agent'], // Only Agents and Admins can see this
  screens: [TicketSidebarScreenType.TicketDetailView],
  icon: 'check-circle',
  order: 50,
  // Only show for agents and admins who can actually manage tickets
  available: (context: TicketSidebarContext) => {
    return context.ticket?.id && context.isTicketAgent
  },
}



