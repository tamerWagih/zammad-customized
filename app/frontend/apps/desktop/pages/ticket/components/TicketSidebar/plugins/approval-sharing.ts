import type { TicketSidebarContext } from '#desktop/pages/ticket/types/sidebar.ts'
import TicketApprovalAndSharePanel from '#shared/components/TicketApprovalAndShare/TicketApprovalAndSharePanel.vue'

export default {
  name: 'approval-sharing',
  label: 'Approval & Sharing',
  icon: 'check-circle',
  component: TicketApprovalAndSharePanel,
  props: (context: TicketSidebarContext) => ({
    ticketId: context.ticket?.id,
    canManage: context.isTicketEditable,
  }),
}



