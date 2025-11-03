import { ref, watch } from 'vue'
import type { Ref } from 'vue'

interface Group {
  id: string
  name: string
  fullname?: string
}

interface Share {
  id: string
  ticketId: string
  groupId: string
  group: Group | string
  sharedById: string
  sharedByName?: string
  permissions: string[]
  message?: string
  status: 'active' | 'revoked'
  createdAt: string
  updatedAt: string
}

interface TicketSharesData {
  ticketShares: Share[]
}

export function useTicketShares(ticketId: Ref<number | undefined>) {
  const data = ref<TicketSharesData | null>(null)
  const loading = ref(false)
  const error = ref<Error | null>(null)

  const fetchShares = async () => {
    if (!ticketId.value) {
      data.value = null
      return
    }

    loading.value = true
    error.value = null

    try {
      const response = await fetch(`/api/v1/tickets/${ticketId.value}/shares`, {
        headers: {
          Accept: 'application/json',
        },
        credentials: 'same-origin',
      })

      if (!response.ok) {
        throw new Error('Failed to fetch shares')
      }

      const result = await response.json()
      data.value = { ticketShares: result.shares || [] }
    } catch (err) {
      error.value = err as Error
      data.value = null
    } finally {
      loading.value = false
    }
  }

  // Watch for ticketId changes
  watch(ticketId, fetchShares, { immediate: true })

  const refetch = () => {
    return fetchShares()
  }

  return {
    data,
    loading,
    error,
    refetch,
  }
}
