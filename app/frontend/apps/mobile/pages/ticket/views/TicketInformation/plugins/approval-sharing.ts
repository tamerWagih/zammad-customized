// Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

import type { TicketInformationPlugin } from './index.ts'

export default <TicketInformationPlugin>{
  label: __('Approval & Sharing'),
  route: {
    path: 'approval-sharing',
    name: 'TicketInformationApprovalSharing',
    props: (route) => ({ internalId: Number(route.params.internalId) }),
    component: () => import('../TicketInformationApprovalSharing.vue'),
    meta: {
      requiresAuth: true,
      requiredPermission: ['ticket.agent'],
    },
  },
  order: 300,
}
