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
            <label for="sharedWith">{{ $t('Share with') }}</label>
            <select 
              id="sharedWith"
              v-model="form.sharedWithId"
              required
              class="form-control"
            >
              <option value="">{{ $t('Select a user') }}</option>
              <option 
                v-for="user in users" 
                :key="user.id" 
                :value="user.id"
              >
                {{ user.fullname }}
              </option>
            </select>
          </div>
          
          <div class="form-group">
            <label>{{ $t('Permissions') }}</label>
            <div class="permissions-list">
              <label class="permission-item">
                <input 
                  type="checkbox" 
                  v-model="form.permissions"
                  value="read"
                >
                {{ $t('Read') }}
              </label>
              <label class="permission-item">
                <input 
                  type="checkbox" 
                  v-model="form.permissions"
                  value="comment"
                >
                {{ $t('Comment') }}
              </label>
              <label class="permission-item">
                <input 
                  type="checkbox" 
                  v-model="form.permissions"
                  value="edit"
                >
                {{ $t('Edit') }}
              </label>
            </div>
          </div>
          
          <div class="form-group">
            <label for="message">{{ $t('Message (Optional)') }}</label>
            <textarea 
              id="message"
              v-model="form.message"
              class="form-control"
              rows="3"
              :placeholder="$t('Add a message for the recipient...')"
            ></textarea>
          </div>
          
          <div class="form-actions">
            <button 
              type="button" 
              @click="$emit('close')"
              class="btn btn-secondary"
            >
              {{ $t('Cancel') }}
            </button>
            <button 
              type="submit" 
              :disabled="loading || form.permissions.length === 0"
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
import { ref, reactive, computed } from 'vue'
import { useUsers } from '#shared/entities/user/composables/useUsers'

interface Props {
  ticketId?: number
}

const props = defineProps<Props>()

const emit = defineEmits<{
  close: []
  created: []
}>()

const loading = ref(false)

const form = reactive({
  sharedWithId: '',
  permissions: [] as string[],
  message: ''
})

const { data: usersData, loading: usersLoading } = useUsers()
const users = computed(() => usersData.value?.users || [])

const submitShare = async () => {
  if (!props.ticketId || !form.sharedWithId || form.permissions.length === 0) return
  
  loading.value = true
  
  try {
    // TODO: Implement share creation mutation
    console.log('Creating share:', {
      ticketId: props.ticketId,
      sharedWithId: form.sharedWithId,
      permissions: form.permissions,
      message: form.message
    })
    
    // Reset form
    form.sharedWithId = ''
    form.permissions = []
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

.permissions-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.permission-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: normal;
  cursor: pointer;
}

.permission-item input[type="checkbox"] {
  margin: 0;
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
