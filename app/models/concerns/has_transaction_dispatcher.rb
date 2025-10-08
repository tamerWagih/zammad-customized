# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module HasTransactionDispatcher
  extend ActiveSupport::Concern

  included do
    after_create TransactionDispatcher
    after_update TransactionDispatcher
  end

  # Add debugging to see if callbacks are triggered
  def self.included(base)
    base.class_eval do
      after_create :log_transaction_dispatcher_create
      after_update :log_transaction_dispatcher_update
    end
  end

  private

  def log_transaction_dispatcher_create
    if self.class.name == 'Ticket::Approval' || self.class.name == 'Ticket::Share'
      Rails.logger.info "[HAS_TRANSACTION_DISPATCHER] 🎯 CREATE callback triggered for #{self.class.name} ##{id}"
    end
  end

  def log_transaction_dispatcher_update
    if self.class.name == 'Ticket::Approval' || self.class.name == 'Ticket::Share'
      Rails.logger.info "[HAS_TRANSACTION_DISPATCHER] 🎯 UPDATE callback triggered for #{self.class.name} ##{id}"
    end
  end
end
