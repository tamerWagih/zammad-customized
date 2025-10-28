<template>
  <div class="flex flex-col gap-2">
    <div v-if="loading" class="flex justify-center py-4">
      <CommonLoader />
    </div>
    
    <div v-else-if="error" class="text-red-600 text-center py-4">
      {{ $t('Error loading approvals') }}
    </div>
    
    <div v-else-if="approvals.length === 0" class="text-center py-4 text-gray-500">
      {{ $t('No approval requests found') }}
    </div>
    
    <div v-else class="flex flex-col gap-2">
      <div 
        v-for="approval in approvals" 
        :key="approval.id"
        class="flex w-full flex-col rounded-lg bg-blue-200 px-2.5 py-2 dark:bg-gray-700"
      >
        <div class="flex items-center justify-between mb-2">
          <div class="flex flex-col">
            <CommonLabel size="small" class="font-medium">
              {{ getApproverName(approval) }}
            </CommonLabel>
            <CommonLabel size="small" class="text-stone-200! dark:text-neutral-500!">
              <CommonDateTime :date-time="approval.createdAt" />
            </CommonLabel>
          </div>
          <CommonLabel 
            size="small" 
            class="px-2 py-1 rounded"
            :class="{
              'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200': approval.status === 'pending',
              'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200': approval.status === 'approved',
              'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200': approval.status === 'rejected'
            }"
          >
            {{ $t(approval.status.charAt(0).toUpperCase() + approval.status.slice(1)) }}
          </CommonLabel>
        </div>
        
        <div v-if="approval.message" class="text-sm text-gray-600 dark:text-gray-300 mb-2">
          {{ approval.message }}
        </div>
        
        <!-- Actions for the approver (approve/reject buttons) -->
        <div v-if="canApprove(approval)" class="flex gap-2 mb-2">
          <CommonButton
            size="small"
            variant="submit"
            :disabled="actionLoading"
            @click="approveApproval(approval.id)"
          >
            {{ $t('Approve') }}
          </CommonButton>
          <CommonButton
            size="small"
            variant="remove"
            :disabled="actionLoading"
            @click="rejectApproval(approval.id)"
          >
            {{ $t('Reject') }}
          </CommonButton>
        </div>
        
        <!-- Management actions for ticket owner (edit/delete) -->
        <div v-if="canManage && approval.status === 'pending'" class="flex gap-2">
          <CommonButton
            size="small"
            variant="secondary"
            :disabled="actionLoading"
            @click="editApproval(approval)"
          >
            {{ $t('Edit') }}
          </CommonButton>
          <CommonButton
            size="small"
            variant="danger"
            :disabled="actionLoading"
            @click="deleteApproval(approval.id)"
          >
            {{ $t('Delete') }}
          </CommonButton>
        </div>
      </div>
    </div>
    
    <CommonButton
      v-if="canManage"
      size="medium"
      class="self-end mt-2"
      icon="plus-square-fill"
      @click="showCreateForm = true"
    >
      {{ $t('Request Approval') }}
    </CommonButton>
    
    <TicketApprovalCreate 
      v-if="showCreateForm"
      :ticket-id="ticketId"
      @close="showCreateForm = false"
      @created="handleApprovalCreated"
    />
    
    <TicketApprovalEdit 
      v-if="showEditForm"
      :ticket-id="ticketId"
      :approval="editingApproval"
      @close="showEditForm = false"
      @updated="handleApprovalUpdated"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

import CommonButton from '#mobile/components/CommonButton/CommonButton.vue'
import CommonDateTime from '#shared/components/CommonDateTime/CommonDateTime.vue'
import CommonLabel from '#shared/components/CommonLabel/CommonLabel.vue'
import CommonLoader from '#mobile/components/CommonLoader/CommonLoader.vue'
import { useTicketApprovals } from '#shared/entities/ticket-approval/composables/useTicketApprovals'
import { useSessionStore } from '#shared/stores/session.ts'

import TicketApprovalCreate from './TicketApprovalCreate.vue'
import TicketApprovalEdit from './TicketApprovalEdit.vue'

interface Props {
  ticketId?: number
  canManage?: boolean
}

const props = defineProps<Props>()

const showCreateForm = ref(false)
const showEditForm = ref(false)
const editingApproval = ref<any>(null)
const actionLoading = ref(false)

const sessionStore = useSessionStore()
const currentUserId = computed(() => sessionStore.user?.id?.toString())

const { 
  data: approvalsData, 
  loading, 
  error,
  refetch 
} = useTicketApprovals(computed(() => props.ticketId))

const approvals = computed(() => approvalsData.value?.ticketApprovals || [])

const getApproverName = (approval: any) => {
  if (typeof approval.approver === 'object') {
    return approval.approver?.fullname || 'Unknown'
  }
  return approval.approver || 'Unknown'
}

const canApprove = (approval: any) => {
  return (
    currentUserId.value &&
    approval.approverId === currentUserId.value &&
    approval.status === 'pending'
  )
}

const confirmAction = (message: string): Promise<boolean> => {
  return new Promise((resolve) => {
    if (window.confirm(message)) {
      resolve(true)
    } else {
      resolve(false)
    }
  })
}

const approveApproval = async (approvalId: number) => {
  if (!props.ticketId) return
  
  const confirmed = await confirmAction('Are you sure you want to approve this request?')
  if (!confirmed) return
  
  actionLoading.value = true
  
  try {
    const response = await fetch(
      `/api/v1/tickets/${props.ticketId}/approvals/${approvalId}/approve`,
      {
        method: 'POST',
        headers: {
          Accept: 'application/json',
        },
        credentials: 'same-origin',
      }
    )

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}))
      throw new Error(errorBody.error || response.statusText)
    }

    await refetch()
  } catch (error) {
    console.error('Error approving approval:', error)
    alert('Failed to approve. Please try again.')
  } finally {
    actionLoading.value = false
  }
}

const rejectApproval = async (approvalId: number) => {
  if (!props.ticketId) return
  
  const confirmed = await confirmAction('Are you sure you want to reject this request?')
  if (!confirmed) return
  
  actionLoading.value = true
  
  try {
    const response = await fetch(
      `/api/v1/tickets/${props.ticketId}/approvals/${approvalId}/reject`,
      {
        method: 'POST',
        headers: {
          Accept: 'application/json',
        },
        credentials: 'same-origin',
      }
    )

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}))
      throw new Error(errorBody.error || response.statusText)
    }

    await refetch()
  } catch (error) {
    console.error('Error rejecting approval:', error)
    alert('Failed to reject. Please try again.')
  } finally {
    actionLoading.value = false
  }
}

const editApproval = (approval: any) => {
  editingApproval.value = approval
  showEditForm.value = true
}

const deleteApproval = async (approvalId: number) => {
  if (!props.ticketId) return
  
  const confirmed = await confirmAction('Are you sure you want to delete this approval request?')
  if (!confirmed) return
  
  actionLoading.value = true
  
  try {
    const response = await fetch(
      `/api/v1/tickets/${props.ticketId}/approvals/${approvalId}`,
      {
        method: 'DELETE',
        headers: {
          Accept: 'application/json',
        },
        credentials: 'same-origin',
      }
    )

    if (!response.ok && response.status !== 404) {
      const errorBody = await response.json().catch(() => ({}))
      throw new Error(errorBody.error || response.statusText)
    }

    await refetch()
  } catch (error) {
    console.error('Error deleting approval:', error)
    alert('Failed to delete. Please try again.')
  } finally {
    actionLoading.value = false
  }
}

const handleApprovalCreated = () => {
  showCreateForm.value = false
  refetch()
}

const handleApprovalUpdated = () => {
  showEditForm.value = false
  editingApproval.value = null
  refetch()
}
</script>
