<!-- Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { ref } from 'vue'
import { useTicketQuery } from '#desktop/pages/ticket/composables/useTicketQuery.ts'
import TicketApprovalList from '#shared/components/TicketApproval/TicketApprovalList.vue'
import TicketShareList from '#shared/components/TicketShare/TicketShareList.vue'

interface Props {
  context: any
  sidebarPlugin: any
}

defineProps<Props>()

const { ticketQuery } = useTicketQuery()
const activeTab = ref<'approvals' | 'shares'>('approvals')
</script>

<template>
  <div class="ticket-approval-share-panel">
    <div v-if="ticketQuery?.ticket?.id" class="panel-content">
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
          :ticket-id="ticketQuery?.ticket?.id"
          :can-manage="ticketQuery?.ticket?.isTicketEditable"
        />
        <TicketShareList 
          v-if="activeTab === 'shares'" 
          :ticket-id="ticketQuery?.ticket?.id"
          :can-manage="ticketQuery?.ticket?.isTicketEditable"
        />
      </div>
    </div>
    <div v-else class="no-ticket">
      {{ $t('No ticket selected') }}
    </div>
  </div>
</template>

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
