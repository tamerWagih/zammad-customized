import { useQuery } from '@vue/apollo-composable'
import { gql } from '@apollo/client/core'

const USERS_QUERY = gql`
  query Users {
    users {
      id
      fullname
      email
      active
    }
  }
`

export function useUsers() {
  return useQuery(USERS_QUERY, {}, {
    errorPolicy: 'all'
  })
}
