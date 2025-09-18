<template>
  <div class="ticket-approval-share-panel">
    <div v-if="ticketId" class="panel-content">
      <div class="tabs">
        <button 
          :class="{ active: activeTab === 'approvals' }"
          @click="activeTab = 'approvals'"
          class="tab-button"
        >
          {{ $t('Approvals') }}
        </button>
        <button 
          :class="{ active: activeTab === 'shares' }"
          @click="activeTab = 'shares'"
          class="tab-button"
        >
          {{ $t('Shares') }}
        </button>
      </div>
      
      <div class="tab-content">
        <TicketApprovalList 
          v-if="activeTab === 'approvals'" 
          :ticket-id="ticketId"
          :can-manage="canManage"
        />
        <TicketShareList 
          v-if="activeTab === 'shares'" 
          :ticket-id="ticketId"
          :can-manage="canManage"
        />
      </div>
    </div>
    <div v-else class="no-ticket">
      {{ $t('No ticket selected') }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import TicketApprovalList from '#shared/components/TicketApproval/TicketApprovalList.vue'
import TicketShareList from '#shared/components/TicketShare/TicketShareList.vue'

interface Props {
  ticketId?: number
  canManage?: boolean
}

defineProps<Props>()

const activeTab = ref<'approvals' | 'shares'>('approvals')
</script>

<style scoped>
.ticket-approval-share-panel {
  padding: 16px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.tabs {
  display: flex;
  border-bottom: 1px solid #e5e7eb;
  margin-bottom: 16px;
}

.tab-button {
  padding: 8px 16px;
  border: none;
  background: none;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  color: #6b7280;
  font-weight: 500;
}

.tab-button.active {
  color: #3b82f6;
  border-bottom-color: #3b82f6;
}

.tab-button:hover {
  color: #374151;
}

.tab-content {
  min-height: 200px;
}

.no-ticket {
  padding: 32px;
  text-align: center;
  color: #6b7280;
  font-style: italic;
}
</style>
