import { useQuery } from '@vue/apollo-composable'
import { gql } from '@apollo/client/core'
import type * as VueCompositionApi from 'vue'

const TICKET_SHARES_QUERY = gql`
  query TicketShares($ticketId: String!) {
    ticketShares(ticketId: $ticketId) {
      id
      ticketId
      sharedWithId
      sharedWith {
        id
        fullname
        email
      }
      permissions
      message
      createdAt
      updatedAt
    }
  }
`

export function useTicketShares(ticketId: VueCompositionApi.Ref<number | undefined>) {
  return useQuery(TICKET_SHARES_QUERY, 
    () => ({ ticketId: ticketId.value?.toString() }),
    {
      skip: VueCompositionApi.computed(() => !ticketId.value),
      errorPolicy: 'all'
    }
  )
}




