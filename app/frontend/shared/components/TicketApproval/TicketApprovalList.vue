<template>
  <div class="ticket-approval-list">
    <div class="header">
      <h3>{{ $t('Approval Requests') }}</h3>
      <button 
        v-if="canManage"
        @click="showCreateForm = true"
        class="btn btn-primary btn-sm"
      >
        {{ $t('Request Approval') }}
      </button>
    </div>
    
    <div v-if="loading" class="loading">
      {{ $t('Loading...') }}
    </div>
    
    <div v-else-if="error" class="error">
      {{ $t('Error loading approvals') }}
    </div>
    
    <div v-else-if="approvals.length === 0" class="empty">
      {{ $t('No approval requests found') }}
    </div>
    
    <div v-else class="approvals">
      <div 
        v-for="approval in approvals" 
        :key="approval.id"
        class="approval-item"
      >
        <div class="approval-info">
          <div class="approver">{{ approval.approver?.fullname }}</div>
          <div class="status" :class="approval.status">
            {{ $t(approval.status) }}
          </div>
          <div class="created">{{ formatDate(approval.createdAt) }}</div>
        </div>
        <div class="approval-actions">
          <button 
            v-if="canManage && approval.status === 'pending'"
            @click="approveApproval(approval.id)"
            class="btn btn-success btn-sm"
          >
            {{ $t('Approve') }}
          </button>
          <button 
            v-if="canManage && approval.status === 'pending'"
            @click="rejectApproval(approval.id)"
            class="btn btn-danger btn-sm"
          >
            {{ $t('Reject') }}
          </button>
        </div>
      </div>
    </div>
    
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

<style scoped>
.ticket-approval-list {
  padding: 16px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.loading, .error, .empty {
  padding: 32px;
  text-align: center;
  color: #6b7280;
}

.error {
  color: #dc2626;
}

.approvals {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.approval-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background-color: #f9fafb;
}

.approval-info {
  flex: 1;
}

.approver {
  font-weight: 500;
  margin-bottom: 4px;
}

.status {
  font-size: 12px;
  padding: 2px 8px;
  border-radius: 12px;
  text-transform: uppercase;
  font-weight: 500;
}

.status.pending {
  background-color: #fef3c7;
  color: #92400e;
}

.status.approved {
  background-color: #d1fae5;
  color: #065f46;
}

.status.rejected {
  background-color: #fee2e2;
  color: #991b1b;
}

.created {
  font-size: 12px;
  color: #6b7280;
  margin-top: 4px;
}

.approval-actions {
  display: flex;
  gap: 8px;
}

.btn {
  padding: 4px 12px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  font-weight: 500;
}

.btn-primary {
  background-color: #3b82f6;
  color: white;
}

.btn-success {
  background-color: #10b981;
  color: white;
}

.btn-danger {
  background-color: #ef4444;
  color: white;
}

.btn-sm {
  padding: 2px 8px;
  font-size: 11px;
}
</style>




