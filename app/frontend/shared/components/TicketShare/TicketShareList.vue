<template>
  <div class="ticket-share-list">
    <div class="header">
      <h3>{{ $t('Shared Tickets') }}</h3>
      <button 
        v-if="canManage"
        @click="showCreateForm = true"
        class="btn btn-primary btn-sm"
      >
        {{ $t('Share Ticket') }}
      </button>
    </div>
    
    <div v-if="loading" class="loading">
      {{ $t('Loading...') }}
    </div>
    
    <div v-else-if="error" class="error">
      {{ $t('Error loading shares') }}
    </div>
    
    <div v-else-if="shares.length === 0" class="empty">
      {{ $t('No shares found') }}
    </div>
    
    <div v-else class="shares">
      <div 
        v-for="share in shares" 
        :key="share.id"
        class="share-item"
      >
        <div class="share-info">
          <div class="shared-with">{{ share.sharedWith?.fullname }}</div>
          <div class="permissions">{{ formatPermissions(share.permissions) }}</div>
          <div class="created">{{ formatDate(share.createdAt) }}</div>
        </div>
        <div class="share-actions">
          <button 
            v-if="canManage"
            @click="revokeShare(share.id)"
            class="btn btn-danger btn-sm"
          >
            {{ $t('Revoke') }}
          </button>
        </div>
      </div>
    </div>
    
    <TicketShareCreate 
      v-if="showCreateForm"
      :ticket-id="ticketId"
      @close="showCreateForm = false"
      @created="handleShareCreated"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useTicketShares } from '#shared/entities/ticket-share/composables/useTicketShares'
import TicketShareCreate from './TicketShareCreate.vue'

interface Props {
  ticketId?: number
  canManage?: boolean
}

const props = defineProps<Props>()

const showCreateForm = ref(false)

const { 
  data: sharesData, 
  loading, 
  error,
  refetch 
} = useTicketShares(computed(() => props.ticketId))

const shares = computed(() => sharesData.value?.ticketShares || [])

const formatDate = (date: string) => {
  return new Date(date).toLocaleDateString()
}

const formatPermissions = (permissions: string[]) => {
  return permissions.join(', ')
}

const revokeShare = async (shareId: number) => {
  // TODO: Implement share revocation mutation
  console.log('Revoking share:', shareId)
  await refetch()
}

const handleShareCreated = () => {
  showCreateForm.value = false
  refetch()
}
</script>

<style scoped>
.ticket-share-list {
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

.shares {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.share-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background-color: #f9fafb;
}

.share-info {
  flex: 1;
}

.shared-with {
  font-weight: 500;
  margin-bottom: 4px;
}

.permissions {
  font-size: 12px;
  color: #6b7280;
  margin-bottom: 4px;
}

.created {
  font-size: 12px;
  color: #6b7280;
}

.share-actions {
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

.btn-danger {
  background-color: #ef4444;
  color: white;
}

.btn-sm {
  padding: 2px 8px;
  font-size: 11px;
}
</style>
