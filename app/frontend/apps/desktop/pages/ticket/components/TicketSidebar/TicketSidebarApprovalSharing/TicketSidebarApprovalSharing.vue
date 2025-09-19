<!-- Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import {
  type TicketSidebarProps,
  type TicketSidebarEmits,
} from '#desktop/pages/ticket/types/sidebar.ts'

import TicketSidebarWrapper from '../TicketSidebarWrapper.vue'

import TicketSidebarApprovalSharingContent from './TicketSidebarApprovalSharingContent.vue'

const props = defineProps<TicketSidebarProps>()

const emit = defineEmits<TicketSidebarEmits>()

emit('show')
</script>

<template>
  <TicketSidebarWrapper
    :key="sidebar"
    :sidebar="sidebar"
    :sidebar-plugin="sidebarPlugin"
    :selected="selected"
  >
    <TicketSidebarApprovalSharingContent
      :context="context"
      :sidebar-plugin="sidebarPlugin"
    />
  </TicketSidebarWrapper>
</template>
