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
    
    # Log all registered backends
    backends = Setting.where(area: 'Transaction::Backend::Async').reorder(:name)
    backends.each do |setting|
    end
    
    backends.each do |setting|
      backend = Setting.get(setting.name)
      next if params[:disable]&.include?(backend)

      
      # Add detailed logging for notification backends
      if backend == 'Transaction::Notification' || backend == 'Transaction::ApprovalNotification' || backend == 'Transaction::ShareNotification' || backend == 'Transaction::CcNotification'
      end
      
      TransactionDispatcher.execute_single_backend(backend.constantize, item, params)
    end
  end
end
