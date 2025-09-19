import type { TicketSidebarContext } from '#desktop/pages/ticket/types/sidebar.ts'
import TicketApprovalAndSharePanel from '#shared/components/TicketApprovalAndShare/TicketApprovalAndSharePanel.vue'

export default {
  title: 'Approval & Sharing',
  order: 50,
  component: TicketApprovalAndSharePanel,
  permissions: ['ticket.agent'],
  screens: ['desktop'],
  icon: 'check-circle',
  available: (context: TicketSidebarContext) => !!context.ticket?.id,
  props: (context: TicketSidebarContext) => ({
    ticketId: context.ticket?.id,
    canManage: context.isTicketEditable,
  }),
}



