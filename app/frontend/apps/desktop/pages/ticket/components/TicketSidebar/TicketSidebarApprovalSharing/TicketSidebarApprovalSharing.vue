<!-- Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'

import { usePersistentStates } from '#desktop/pages/ticket/composables/usePersistentStates.ts'
import {
  type TicketSidebarProps,
  type TicketSidebarEmits,
} from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarWrapper from '../TicketSidebarWrapper.vue'

import TicketSidebarApprovalSharingContent from './TicketSidebarApprovalSharingContent.vue'

import { useTicketInformation } from '#desktop/pages/ticket/composables/useTicketInformation.ts'
import { useTicketView } from '#shared/entities/ticket/composables/useTicketView.ts'
import { useSessionStore } from '#shared/stores/session.ts'

defineProps<TicketSidebarProps>()

const { persistentStates } = usePersistentStates()

const emit = defineEmits<TicketSidebarEmits>()

onMounted(() => {
  emit('show')
})

// Align visibility handling with other sidebar components (e.g., attachments)
const { ticket } = useTicketInformation()
const { isTicketAgent } = useTicketView(ticket)
const { hasPermission } = useSessionStore()

const canManageApprovals = computed(
  () => isTicketAgent.value || hasPermission(['admin.*']),
)
const canManageShares = computed(
  () => isTicketAgent.value || hasPermission(['admin.*']),
)

const isVisible = computed(() => !!ticket.value?.id && (canManageApprovals.value || canManageShares.value))

watch(
  isVisible,
  (visible) => {
    emit(visible ? 'show' : 'hide')
  },
)
</script>

<template>
  <TicketSidebarWrapper
    :key="sidebar"
    :sidebar="sidebar"
    :sidebar-plugin="sidebarPlugin"
    :selected="selected"
  >
    <TicketSidebarApprovalSharingContent
      v-model="persistentStates"
      :context="context"
      :sidebar-plugin="sidebarPlugin"
    />
  </TicketSidebarWrapper>
</template>
