// Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

import type { TicketInformationPlugin } from './index.ts'
import TicketInformationApprovalSharing from '../TicketInformationApprovalSharing.vue'

export default <TicketInformationPlugin>{
  label: __('Approval & Sharing'),
  route: {
    path: 'approval-sharing',
    name: 'TicketInformationApprovalSharing',
    component: TicketInformationApprovalSharing,
    meta: {
      requiresAuth: true,
      requiredPermission: ['ticket.agent'],
    },
  },
  order: 300,
}
