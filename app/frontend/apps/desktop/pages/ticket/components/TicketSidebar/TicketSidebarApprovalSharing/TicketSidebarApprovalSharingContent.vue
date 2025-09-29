<!-- Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed } from 'vue'

import { useTicketView } from '#shared/entities/ticket/composables/useTicketView.ts'
import type { ObjectLike } from '#shared/types/utils.ts'
import { useSessionStore } from '#shared/stores/session.ts'

import CommonSectionCollapse from '#desktop/components/CommonSectionCollapse/CommonSectionCollapse.vue'
import { useTicketInformation } from '#desktop/pages/ticket/composables/useTicketInformation.ts'
import { type TicketSidebarContentProps } from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarContent from '../TicketSidebarContent.vue'

import TicketApprovalList from '#shared/components/TicketApproval/TicketApprovalList.vue'
import TicketShareList from '#shared/components/TicketShare/TicketShareList.vue'

const props = defineProps<TicketSidebarContentProps>()

const persistentStates = defineModel<ObjectLike>({ required: true })

const { ticket } = useTicketInformation()
const { isTicketAgent, isTicketEditable } = useTicketView(ticket)
const { hasPermission } = useSessionStore()

// Role-based permissions - allow both agents and admins
const canManageApprovals = computed(() => isTicketAgent.value || hasPermission(['admin.*']))
const canManageShares = computed(() => isTicketAgent.value || hasPermission(['admin.*']))
</script>

<template>
  <TicketSidebarContent
    v-model="persistentStates.scrollPosition"
    :title="sidebarPlugin.title"
    :icon="sidebarPlugin.icon"
  >
    <CommonSectionCollapse
      v-if="ticket?.id && canManageApprovals"
      id="ticket-approvals"
      v-model="persistentStates.collapseApprovals"
      :title="__('Approvals')"
    >
      <TicketApprovalList 
        :ticket-id="ticket.id"
        :can-manage="canManageApprovals"
      />
    </CommonSectionCollapse>

    <CommonSectionCollapse
      v-if="ticket?.id && canManageShares"
      id="ticket-shares"
      v-model="persistentStates.collapseShares"
      :title="__('Shares')"
    >
      <TicketShareList 
        :ticket-id="ticket.id"
        :can-manage="canManageShares"
      />
    </CommonSectionCollapse>

    <div v-if="!ticket?.id" class="no-ticket">
      {{ $t('Please select a ticket to view approvals and shares.') }}
    </div>
  </TicketSidebarContent>
</template>

<style scoped>
.no-ticket {
  padding: 2rem;
  text-align: center;
  color: var(--theme-text-color-light);
  font-style: italic;
}
</style>
