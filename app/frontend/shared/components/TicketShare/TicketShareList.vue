<template>
  <div class="flex flex-col gap-2">
    <div v-if="loading" class="flex justify-center py-4">
      <CommonLoader />
    </div>
    
    <div v-else-if="error" class="text-red-600 text-center py-4">
      {{ $t('Error loading shares') }}
    </div>
    
    <div v-else-if="shares.length === 0" class="text-center py-4 text-gray-500">
      {{ $t('No shares found') }}
    </div>
    
    <div v-else class="flex flex-col gap-2">
      <div 
        v-for="share in shares" 
        :key="share.id"
        class="flex w-full flex-col rounded-lg px-2.5 py-2"
        :class="{
          'bg-blue-200 dark:bg-gray-700': share.status === 'active',
          'bg-gray-200 dark:bg-gray-800': share.status === 'revoked'
        }"
      >
        <div class="flex items-center justify-between mb-2">
          <div class="flex flex-col flex-1">
            <CommonLabel size="small" class="font-medium">
              {{ getGroupName(share) }}
            </CommonLabel>
            <CommonLabel size="small" class="text-stone-200! dark:text-neutral-500!">
              <CommonDateTime :date-time="share.createdAt" />
            </CommonLabel>
          </div>
          <CommonLabel 
            size="small" 
            class="px-2 py-1 rounded"
            :class="{
              'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200': share.status === 'active',
              'bg-gray-300 text-gray-700 dark:bg-gray-600 dark:text-gray-300': share.status === 'revoked'
            }"
          >
            {{ share.status === 'active' ? $t('Active') : $t('Revoked') }}
          </CommonLabel>
        </div>
        
        <div v-if="share.message" class="text-sm text-gray-600 dark:text-gray-300 mb-2">
          {{ share.message }}
        </div>
        
        <div v-if="canManage && share.status === 'active'" class="flex gap-2">
          <CommonButton
            size="small"
            variant="secondary"
            :disabled="actionLoading"
            @click="editShare(share)"
          >
            {{ $t('Edit') }}
          </CommonButton>
          <CommonButton
            size="small"
            variant="remove"
            :disabled="actionLoading"
            @click="revokeShare(share.id)"
          >
            {{ $t('Revoke') }}
          </CommonButton>
          <CommonButton
            size="small"
            variant="danger"
            :disabled="actionLoading"
            @click="deleteShare(share.id)"
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
      {{ $t('Share Ticket') }}
    </CommonButton>
    
    <TicketShareCreate 
      v-if="showCreateForm"
      :ticket-id="ticketId"
      @close="showCreateForm = false"
      @created="handleShareCreated"
    />
    
    <TicketShareEdit 
      v-if="showEditForm"
      :ticket-id="ticketId"
      :share="editingShare"
      @close="showEditForm = false"
      @updated="handleShareUpdated"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

import CommonButton from '#mobile/components/CommonButton/CommonButton.vue'
import CommonDateTime from '#shared/components/CommonDateTime/CommonDateTime.vue'
import CommonLabel from '#shared/components/CommonLabel/CommonLabel.vue'
import CommonLoader from '#mobile/components/CommonLoader/CommonLoader.vue'
import { useTicketShares } from '#shared/entities/ticket-share/composables/useTicketShares'

import TicketShareCreate from './TicketShareCreate.vue'
import TicketShareEdit from './TicketShareEdit.vue'

interface Props {
  ticketId?: number
  canManage?: boolean
}

const props = defineProps<Props>()

const showCreateForm = ref(false)
const showEditForm = ref(false)
const editingShare = ref<any>(null)
const actionLoading = ref(false)

const { 
  data: sharesData, 
  loading, 
  error,
  refetch 
} = useTicketShares(computed(() => props.ticketId))

const shares = computed(() => sharesData.value?.ticketShares || [])

const getGroupName = (share: any) => {
  if (typeof share.group === 'object') {
    return share.group?.fullname || share.group?.name || 'Unknown group'
  }
  return share.groupName || share.group || 'Unknown group'
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

const revokeShare = async (shareId: number) => {
  if (!props.ticketId) return
  
  const confirmed = await confirmAction('Are you sure you want to revoke this share?')
  if (!confirmed) return
  
  actionLoading.value = true
  
  try {
    const response = await fetch(
      `/api/v1/tickets/${props.ticketId}/shares/${shareId}/revoke`,
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
    console.error('Error revoking share:', error)
    alert('Failed to revoke share. Please try again.')
  } finally {
    actionLoading.value = false
  }
}

const editShare = (share: any) => {
  editingShare.value = share
  showEditForm.value = true
}

const deleteShare = async (shareId: number) => {
  if (!props.ticketId) return
  
  const confirmed = await confirmAction('Are you sure you want to delete this share?')
  if (!confirmed) return
  
  actionLoading.value = true
  
  try {
    const response = await fetch(
      `/api/v1/tickets/${props.ticketId}/shares/${shareId}`,
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
    console.error('Error deleting share:', error)
    alert('Failed to delete share. Please try again.')
  } finally {
    actionLoading.value = false
  }
}

const handleShareCreated = () => {
  showCreateForm.value = false
  refetch()
}

const handleShareUpdated = () => {
  showEditForm.value = false
  editingShare.value = null
  refetch()
}
</script>
