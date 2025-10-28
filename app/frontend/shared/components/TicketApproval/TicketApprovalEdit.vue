<template>
  <div class="ticket-approval-edit">
    <div class="modal-overlay" @click="$emit('close')">
      <div class="modal-content" @click.stop>
        <div class="modal-header">
          <h3>{{ $t('Edit Approval Request') }}</h3>
          <button @click="$emit('close')" class="close-btn">&times;</button>
        </div>
        
        <form @submit.prevent="submitUpdate" class="approval-form">
          <div class="form-group">
            <label>{{ $t('Approver') }}</label>
            <div class="form-control-static">
              {{ getApproverName(approval) }}
            </div>
            <small class="form-text">{{ $t('The approver cannot be changed') }}</small>
          </div>
          
          <div class="form-group">
            <label for="priority">{{ $t('Priority') }}</label>
            <select 
              id="priority"
              v-model="form.priority"
              class="form-control"
              :disabled="loading"
            >
              <option value="low">{{ $t('Low') }}</option>
              <option value="normal">{{ $t('Normal') }}</option>
              <option value="high">{{ $t('High') }}</option>
              <option value="urgent">{{ $t('Urgent') }}</option>
            </select>
          </div>
          
          <div class="form-group">
            <label for="message">{{ $t('Message (Optional)') }}</label>
            <textarea 
              id="message"
              v-model="form.message"
              class="form-control"
              rows="3"
              :placeholder="$t('Add a message for the approver...')"
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
              :disabled="loading"
              class="btn btn-primary"
            >
              {{ loading ? $t('Updating...') : $t('Update') }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'

interface Props {
  ticketId?: number
  approval: any
}

const props = defineProps<Props>()

const emit = defineEmits<{
  close: []
  updated: []
}>()

const loading = ref(false)

const form = reactive({
  priority: '',
  message: ''
})

onMounted(() => {
  // Initialize form with existing values
  form.priority = props.approval?.priority || 'normal'
  form.message = props.approval?.message || ''
})

const getApproverName = (approval: any) => {
  if (typeof approval?.approver === 'object') {
    return approval.approver?.fullname || 'Unknown'
  }
  return approval?.approver || 'Unknown'
}

const submitUpdate = async () => {
  if (!props.ticketId || !props.approval?.id) return
  
  loading.value = true
  
  try {
    const body = new URLSearchParams()
    body.set('priority', form.priority)
    if (form.message) body.set('message', form.message)

    const response = await fetch(
      `/api/v1/tickets/${props.ticketId}/approvals/${props.approval.id}`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          Accept: 'application/json',
        },
        credentials: 'same-origin',
        body: body.toString(),
      }
    )

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}))
      throw new Error(errorBody.error || response.statusText)
    }
    
    emit('updated')
  } catch (error) {
    console.error('Error updating approval:', error)
    alert('Failed to update approval. Please try again.')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.ticket-approval-edit {
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
  padding: 1rem;
}

.modal-content {
  background: white;
  border-radius: 8px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
  width: 100%;
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

.approval-form {
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
  background-color: white;
}

.form-control-static {
  padding: 8px 12px;
  background-color: #f3f4f6;
  border-radius: 6px;
  color: #374151;
}

.form-text {
  display: block;
  margin-top: 4px;
  font-size: 12px;
  color: #6b7280;
}

.form-control:disabled {
  background-color: #f3f4f6;
  cursor: not-allowed;
}

.form-control:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
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

@media (prefers-color-scheme: dark) {
  .modal-content {
    background: #1f2937;
  }
  
  .modal-header {
    border-bottom-color: #374151;
  }
  
  .modal-header h3 {
    color: #f3f4f6;
  }
  
  .form-group label {
    color: #e5e7eb;
  }
  
  .form-control {
    background-color: #374151;
    border-color: #4b5563;
    color: #f3f4f6;
  }
  
  .form-control-static {
    background-color: #374151;
    color: #e5e7eb;
  }
  
  .form-text {
    color: #9ca3af;
  }
  
  .form-control:disabled {
    background-color: #1f2937;
  }
  
  .close-btn {
    color: #9ca3af;
  }
  
  .close-btn:hover {
    color: #d1d5db;
  }
}
</style>

