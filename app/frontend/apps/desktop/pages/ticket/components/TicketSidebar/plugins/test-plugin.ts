// Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

import { TicketSidebarScreenType } from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarInformation from '../TicketSidebarInformation/TicketSidebarInformation.vue'

import type { TicketSidebarPlugin } from './types.ts'

export default <TicketSidebarPlugin>{
  title: __('Debug Plugin'),
  component: TicketSidebarInformation,
  permissions: ['ticket.agent', 'admin'],
  screens: [TicketSidebarScreenType.TicketDetailView],
  icon: 'bug',
  order: 5,
}
