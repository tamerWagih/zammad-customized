# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TransactionJob < ApplicationJob
  # Override the global setting to ensure TransactionJob is always enqueued
  # even when called from within or after database transactions
  self.enqueue_after_transaction_commit = :default

=begin
  {
    object: 'Ticket',
    type: 'update',
    ticket_id: 123,
    interface_handle: 'application_server', # application_server|websocket|scheduler
    changes: {
      'attribute1' => [before,now],
      'attribute2' => [before,now],
    },
    created_at: Time.zone.now,
    user_id: 123,
  },
=end

  def perform(item, params = {})
    Rails.logger.info "[TRANSACTION_JOB] 🔄 Processing item: #{item[:object]} ##{item[:object_id]} (#{item[:type]})"
    
    # Log all registered backends
    backends = Setting.where(area: 'Transaction::Backend::Async').reorder(:name)
    Rails.logger.info "[TRANSACTION_JOB] 📋 Total async backends found: #{backends.count}"
    backends.each do |setting|
      Rails.logger.info "[TRANSACTION_JOB] 📋 Backend: #{setting.name} = #{Setting.get(setting.name)}"
    end
    
    backends.each do |setting|
      backend = Setting.get(setting.name)
      Rails.logger.info "[TRANSACTION_JOB] 📋 Processing backend: #{setting.name} = #{backend}"
      next if params[:disable]&.include?(backend)

      Rails.logger.info "[TRANSACTION_JOB] 🚀 Executing backend: #{backend} for #{item[:object]} ##{item[:object_id]}"
      
      # Add detailed logging for notification backends
      if backend == 'Transaction::Notification' || backend == 'Transaction::ApprovalNotification' || backend == 'Transaction::ShareNotification'
        Rails.logger.info "[TRANSACTION_JOB] 📧 NOTIFICATION BACKEND: #{backend} processing #{item[:object]} #{item[:type]} event"
      end
      
      TransactionDispatcher.execute_single_backend(backend.constantize, item, params)
    end
  end
end
