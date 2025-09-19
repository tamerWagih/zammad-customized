<!-- Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useTicketView } from '#shared/entities/ticket/composables/useTicketView.ts'
import { useTicketInformation } from '#desktop/pages/ticket/composables/useTicketInformation.ts'
import { type TicketSidebarContentProps } from '#desktop/pages/ticket/types/sidebar.ts'
import TicketSidebarContent from '../TicketSidebarContent.vue'
import TicketApprovalList from '#shared/components/TicketApproval/TicketApprovalList.vue'
import TicketShareList from '#shared/components/TicketShare/TicketShareList.vue'

const props = defineProps<TicketSidebarContentProps>()

const { ticket } = useTicketInformation()
const { isTicketAgent, isTicketEditable } = useTicketView(ticket)

const activeTab = ref<'approvals' | 'shares'>('approvals')

// Role-based permissions
const canManageApprovals = computed(() => isTicketAgent.value)
const canManageShares = computed(() => isTicketAgent.value)
</script>

<template>
  <TicketSidebarContent
    :title="sidebarPlugin.title"
    :icon="sidebarPlugin.icon"
  >
    <div v-if="ticket?.id" class="ticket-approval-share-panel">
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
          :ticket-id="ticket.id"
          :can-manage="canManageApprovals"
        />
        <TicketShareList 
          v-if="activeTab === 'shares'" 
          :ticket-id="ticket.id"
          :can-manage="canManageShares"
        />
      </div>
    </div>
    <div v-else class="no-ticket">
      {{ $t('No ticket selected') }}
    </div>
  </TicketSidebarContent>
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
