# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddPerformanceIndexesToTicketCcs < ActiveRecord::Migration[7.2]
  def change
    # Add index for user_id lookups (used in policy checks)
    add_index :ticket_ccs, :user_id, name: 'index_ticket_ccs_on_user_id'
    
    # Add composite index for notification queries
    add_index :ticket_ccs, [:ticket_id, :user_id], name: 'index_ticket_ccs_on_ticket_and_user_for_notifications'
  end
end
