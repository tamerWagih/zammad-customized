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
        class="flex w-full flex-col rounded-lg bg-blue-200 px-2.5 dark:bg-gray-700"
      >
        <div class="flex items-center justify-between py-2">
          <div class="flex flex-col">
            <CommonLabel size="small" class="font-medium">
              {{ approval.approver?.fullname }}
            </CommonLabel>
            <CommonLabel size="small" class="text-stone-200! dark:text-neutral-500!">
              <CommonDateTime :date-time="approval.createdAt" />
            </CommonLabel>
          </div>
          <CommonLabel 
            size="small" 
            :class="{
              'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200': approval.status === 'pending',
              'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200': approval.status === 'approved',
              'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200': approval.status === 'rejected'
            }"
          >
            {{ $t(approval.status) }}
          </CommonLabel>
        </div>
        
        <div v-if="approval.message" class="text-sm text-gray-600 dark:text-gray-300 mb-2">
          {{ approval.message }}
        </div>
        
        <div v-if="canManage && approval.status === 'pending'" class="flex gap-2">
          <CommonButton
            size="small"
            variant="submit"
            @click="approveApproval(approval.id)"
          >
            {{ $t('Approve') }}
          </CommonButton>
          <CommonButton
            size="small"
            variant="remove"
            @click="rejectApproval(approval.id)"
          >
            {{ $t('Reject') }}
          </CommonButton>
        </div>
      </div>
    </div>
    
    <CommonButton
      v-if="canManage"
      size="medium"
      class="self-end"
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
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

import CommonButton from '#desktop/components/CommonButton/CommonButton.vue'
import CommonDateTime from '#shared/components/CommonDateTime/CommonDateTime.vue'
import CommonLabel from '#shared/components/CommonLabel/CommonLabel.vue'
import CommonLoader from '#desktop/components/CommonLoader/CommonLoader.vue'
import { useTicketApprovals } from '#shared/entities/ticket-approval/composables/useTicketApprovals'

import TicketApprovalCreate from './TicketApprovalCreate.vue'

interface Props {
  ticketId?: number
  canManage?: boolean
}

const props = defineProps<Props>()

const showCreateForm = ref(false)

const { 
  data: approvalsData, 
  loading, 
  error,
  refetch 
} = useTicketApprovals(computed(() => props.ticketId))

const approvals = computed(() => approvalsData.value?.ticketApprovals || [])

const formatDate = (date: string) => {
  return new Date(date).toLocaleDateString()
}

const approveApproval = async (approvalId: number) => {
  // TODO: Implement approval mutation
  console.log('Approving approval:', approvalId)
  await refetch()
}

const rejectApproval = async (approvalId: number) => {
  // TODO: Implement rejection mutation
  console.log('Rejecting approval:', approvalId)
  await refetch()
}

const handleApprovalCreated = () => {
  showCreateForm.value = false
  refetch()
}
</script>





