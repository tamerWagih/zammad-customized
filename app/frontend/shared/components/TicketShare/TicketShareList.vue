<template>
  <div class="flex flex-col gap-2">
    <div v-if="loading" class="flex justify-center py-4">
      <CommonLoader />
    </div>
    
    <div v-else-if="error" class="text-red-600 text-center py-4">
      {{ $t('Error loading shares') }}
    </div>
    
    <div v-else-if="shares.length === 0" class="text-center py-4 text-gray-500">
      {{ $t('No shares found') }}
    </div>
    
    <div v-else class="flex flex-col gap-2">
      <div 
        v-for="share in shares" 
        :key="share.id"
        class="flex w-full flex-col rounded-lg bg-blue-200 px-2.5 dark:bg-gray-700"
      >
        <div class="flex items-center justify-between py-2">
          <div class="flex flex-col">
            <CommonLabel size="small" class="font-medium">
              {{ share.group?.fullname || share.group?.name || $t('Unknown group') }}
            </CommonLabel>
            <CommonLabel size="small" class="text-stone-200! dark:text-neutral-500!">
              <CommonDateTime :date-time="share.createdAt" />
            </CommonLabel>
          </div>
          <CommonLabel size="small" class="bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
            {{ $t('Full access') }}
          </CommonLabel>
        </div>
        
        <div v-if="share.message" class="text-sm text-gray-600 dark:text-gray-300 mb-2">
          {{ share.message }}
        </div>
        
        <div v-if="share.expiresAt" class="text-xs text-gray-500 dark:text-gray-400 mb-2">
          {{ $t('Expires {date}', { date: $d(new Date(share.expiresAt), 'short') }) }}
        </div>
        
        <div v-if="canManage" class="flex gap-2">
          <CommonButton
            size="small"
            variant="remove"
            @click="revokeShare(share.id)"
          >
            {{ $t('Revoke') }}
          </CommonButton>
        </div>
      </div>
    </div>
    
    <CommonButton
      v-if="canManage"
      size="medium"
      class="self-end"
      icon="plus-square-fill"
      @click="showCreateForm = true"
    >
      {{ $t('Share Ticket') }}
    </CommonButton>
    
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

import CommonButton from '#desktop/components/CommonButton/CommonButton.vue'
import CommonDateTime from '#shared/components/CommonDateTime/CommonDateTime.vue'
import CommonLabel from '#shared/components/CommonLabel/CommonLabel.vue'
import CommonLoader from '#desktop/components/CommonLoader/CommonLoader.vue'
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

const revokeShare = async (shareId: number) => {
  console.log('Revoke share not yet implemented', shareId)
  await refetch()
}

const handleShareCreated = () => {
  showCreateForm.value = false
  refetch()
}
</script>


