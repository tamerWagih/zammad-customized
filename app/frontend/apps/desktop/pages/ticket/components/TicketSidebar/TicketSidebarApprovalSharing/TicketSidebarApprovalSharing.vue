<!-- Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { onMounted } from 'vue'

import { usePersistentStates } from '#desktop/pages/ticket/composables/usePersistentStates.ts'
import {
  type TicketSidebarProps,
  type TicketSidebarEmits,
} from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarWrapper from '../TicketSidebarWrapper.vue'

import TicketSidebarApprovalSharingContent from './TicketSidebarApprovalSharingContent.vue'

defineProps<TicketSidebarProps>()

const { persistentStates } = usePersistentStates()

const emit = defineEmits<TicketSidebarEmits>()

onMounted(() => {
  emit('show')
})
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
