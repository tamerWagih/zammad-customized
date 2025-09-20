<!-- Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed } from 'vue'

import { useTicketInformation } from '#mobile/pages/ticket/composable/useTicketInformation.ts'
import { useSessionStore } from '#shared/stores/session.ts'

import TicketApprovalList from '#shared/components/TicketApproval/TicketApprovalList.vue'
import TicketShareList from '#shared/components/TicketShare/TicketShareList.vue'

interface Props {
  internalId: number
}

const props = defineProps<Props>()

const { ticket } = useTicketInformation()
const { hasPermission } = useSessionStore()

// Role-based permissions - allow both agents and admins
const canManageApprovals = computed(() => hasPermission(['ticket.agent']) || hasPermission(['admin.*']))
const canManageShares = computed(() => hasPermission(['ticket.agent']) || hasPermission(['admin.*']))
</script>

<template>
  <div class="ticket-information-approval-sharing">
    <div v-if="ticket?.id && canManageApprovals" class="approvals-section">
      <h3 class="section-title">{{ $t('Approvals') }}</h3>
      <TicketApprovalList 
        :ticket-id="ticket.id"
        :can-manage="canManageApprovals"
      />
    </div>

    <div v-if="ticket?.id && canManageShares" class="shares-section">
      <h3 class="section-title">{{ $t('Shares') }}</h3>
      <TicketShareList 
        :ticket-id="ticket.id"
        :can-manage="canManageShares"
      />
    </div>

    <div v-if="!ticket?.id" class="no-ticket">
      {{ $t('Please select a ticket to view approvals and shares.') }}
    </div>
  </div>
</template>

<style scoped>
.ticket-information-approval-sharing {
  padding: 1rem;
}

.section-title {
  font-size: 1.1rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
  color: var(--color-text-1);
}

.approvals-section,
.shares-section {
  margin-bottom: 1.5rem;
}

.no-ticket {
  padding: 2rem;
  text-align: center;
  color: var(--color-text-2);
  font-style: italic;
}
</style>
