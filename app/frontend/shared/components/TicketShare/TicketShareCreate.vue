<template>
  <div class="ticket-share-create">
    <div class="modal-overlay" @click="$emit('close')">
      <div class="modal-content" @click.stop>
        <div class="modal-header">
          <h3>{{ $t('Share Ticket') }}</h3>
          <button @click="$emit('close')" class="close-btn">&times;</button>
        </div>
        
        <form @submit.prevent="submitShare" class="share-form">
          <div class="form-group">
            <label for="shareGroup">{{ $t('Share with group') }}</label>
            <select 
              id="shareGroup"
              v-model="form.groupId"
              required
              class="form-control"
              :disabled="groupsLoading || loading"
            >
              <option value="">{{ $t('Select a group to share with...') }}</option>
              <option 
                v-for="group in groups" 
                :key="group.id" 
                :value="group.id"
              >
                {{ group.fullname || group.name }}
              </option>
            </select>
            <small class="form-text text-muted">{{ $t('All members of the selected group receive full access') }}</small>
          </div>
          
          <div class="form-group">
            <label for="message">{{ $t('Message (optional)') }}</label>
            <textarea 
              id="message"
              v-model="form.message"
              class="form-control"
              rows="3"
              :placeholder="$t('Add a message for the group...')"
              :disabled="loading"
            ></textarea>
          </div>
          
          <div class="form-actions">
            <button 
              type="button" 
              @click="$emit('close')"
              class="btn btn-secondary"
              :disabled="loading"
            >
              {{ $t('Cancel') }}
            </button>
            <button 
              type="submit" 
              :disabled="loading || !form.groupId"
              class="btn btn-primary"
            >
              {{ loading ? $t('Sharing...') : $t('Share Ticket') }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'

interface Props {
  ticketId?: number
}

interface GroupOption {
  id: string
  name: string
  fullname?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{
  close: []
  created: []
}>()

const loading = ref(false)
const groupsLoading = ref(false)
const groups = ref<GroupOption[]>([])

const form = reactive({
  groupId: '',
  message: ''
})

const loadGroups = async () => {
  groupsLoading.value = true
  try {
    const response = await fetch('/api/v1/groups', {
      headers: {
        Accept: 'application/json',
      },
      credentials: 'same-origin',
    })

    if (!response.ok) {
      throw new Error(response.statusText)
    }

    const data = await response.json()
    const list = Array.isArray(data) ? data : data?.groups || []

    groups.value = list
      .filter((group: any) => group?.active !== false)
      .map((group: any) => ({
        id: String(group.id),
        name: group.name,
        fullname: group.fullname || (group.name ? group.name.replace(/::/g, " � ") : undefined),
      }))
      .sort((a, b) => (a.fullname || a.name || '').localeCompare(b.fullname || b.name || ''))
  } catch (error) {
    console.error('Failed to load groups for sharing:', error)
    groups.value = []
  } finally {
    groupsLoading.value = false
  }
}

onMounted(loadGroups)

const submitShare = async () => {
  if (!props.ticketId || !form.groupId) return

  loading.value = true

  try {
    const body = new URLSearchParams()
    body.set('group_id', form.groupId)
    if (form.message) body.set('message', form.message)

    const response = await fetch(`/api/v1/tickets/${props.ticketId}/shares`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        Accept: 'application/json',
      },
      credentials: 'same-origin',
      body: body.toString(),
    })

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}))
      throw new Error(errorBody.error || response.statusText)
    }

    form.groupId = ''
    form.message = ''

    emit('created')
  } catch (error) {
    console.error('Error creating share:', error)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.ticket-share-create {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 1000;
}

.modal-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-content {
  background: white;
  border-radius: 8px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
  width: 90%;
  max-width: 500px;
  max-height: 90vh;
  overflow-y: auto;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px;
  border-bottom: 1px solid #e5e7eb;
}

.modal-header h3 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
}

.close-btn {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: #6b7280;
  padding: 0;
  width: 30px;
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.close-btn:hover {
  color: #374151;
}

.share-form {
  padding: 20px;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  margin-bottom: 6px;
  font-weight: 500;
  color: #374151;
}

.form-control {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 14px;
}

.form-control:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.form-text {
  font-size: 12px;
  color: #6b7280;
  margin-top: 4px;
  display: block;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 24px;
}

.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  transition: background-color 0.2s;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-secondary {
  background-color: #6b7280;
  color: white;
}

.btn-secondary:hover:not(:disabled) {
  background-color: #4b5563;
}

.btn-primary {
  background-color: #3b82f6;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background-color: #2563eb;
}
</style>

