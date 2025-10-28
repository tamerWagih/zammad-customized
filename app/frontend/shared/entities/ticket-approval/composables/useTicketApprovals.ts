import { ref, watch } from 'vue'
import type { Ref } from 'vue'

interface Approver {
  id: string
  fullname: string
  email?: string
}

interface Requester {
  id: string
  fullname: string
  email?: string
}

interface Approval {
  id: string
  ticketId: string
  approverId: string
  approver: Approver | string
  requesterId: string
  requester: Requester | string
  status: 'pending' | 'approved' | 'rejected'
  message?: string
  priority?: string
  createdAt: string
  updatedAt: string
}

interface TicketApprovalsData {
  ticketApprovals: Approval[]
}

export function useTicketApprovals(ticketId: Ref<number | undefined>) {
  const data = ref<TicketApprovalsData | null>(null)
  const loading = ref(false)
  const error = ref<Error | null>(null)

  const fetchApprovals = async () => {
    if (!ticketId.value) {
      data.value = null
      return
    }

    loading.value = true
    error.value = null

    try {
      const response = await fetch(`/api/v1/tickets/${ticketId.value}/approvals`, {
        headers: {
          Accept: 'application/json',
        },
        credentials: 'same-origin',
      })

      if (!response.ok) {
        throw new Error('Failed to fetch approvals')
      }

      const result = await response.json()
      data.value = { ticketApprovals: result.approvals || [] }
    } catch (err) {
      error.value = err as Error
      data.value = null
    } finally {
      loading.value = false
    }
  }

  // Watch for ticketId changes
  watch(ticketId, fetchApprovals, { immediate: true })

  const refetch = () => {
    return fetchApprovals()
  }

  return {
    data,
    loading,
    error,
    refetch,
  }
}




