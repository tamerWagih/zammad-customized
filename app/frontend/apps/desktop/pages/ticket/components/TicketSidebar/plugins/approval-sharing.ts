// Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

import { TicketSidebarScreenType } from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarApprovalSharing from '../TicketSidebarApprovalSharing/TicketSidebarApprovalSharing.vue'

import type { TicketSidebarPlugin } from './types.ts'

export default <TicketSidebarPlugin>{
  title: __('Approval & Sharing'),
  component: TicketSidebarApprovalSharing,
  permissions: ['ticket.agent', 'admin'], // Agents and Admins can see this
  screens: [TicketSidebarScreenType.TicketDetailView],
  icon: 'check-circle',
  order: 50,
}



