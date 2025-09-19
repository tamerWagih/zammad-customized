import { useQuery } from '@vue/apollo-composable'
import { gql } from '@apollo/client/core'
import type * as VueCompositionApi from 'vue'

const TICKET_APPROVALS_QUERY = gql`
  query TicketApprovals($ticketId: String!) {
    ticketApprovals(ticketId: $ticketId) {
      id
      ticketId
      approverId
      approver {
        id
        fullname
        email
      }
      status
      message
      createdAt
      updatedAt
    }
  }
`

export function useTicketApprovals(ticketId: VueCompositionApi.Ref<number | undefined>) {
  return useQuery(TICKET_APPROVALS_QUERY, 
    () => ({ ticketId: ticketId.value?.toString() }),
    {
      skip: VueCompositionApi.computed(() => !ticketId.value),
      errorPolicy: 'all'
    }
  )
}



