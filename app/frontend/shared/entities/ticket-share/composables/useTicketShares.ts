import { useQuery } from '@vue/apollo-composable'
import { gql } from '@apollo/client/core'
import type * as VueCompositionApi from 'vue'

const TICKET_SHARES_QUERY = gql`
  query TicketShares($ticketId: String!) {
    ticketShares(ticketId: $ticketId) {
      id
      ticketId
      groupId
      group {
        id
        name
      }
      message
      status
      expiresAt
      createdAt
      updatedAt
    }
  }
`

export function useTicketShares(ticketId: VueCompositionApi.Ref<number | undefined>) {
  return useQuery(
    TICKET_SHARES_QUERY,
    () => ({ ticketId: ticketId.value?.toString() }),
    {
      skip: VueCompositionApi.computed(() => !ticketId.value),
      errorPolicy: 'all',
    },
  )
}
