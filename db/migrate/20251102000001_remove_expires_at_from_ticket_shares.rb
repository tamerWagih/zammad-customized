# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class RemoveExpiresAtFromTicketShares < ActiveRecord::Migration[7.2]
  def change
    # Remove the expires_at index first
    remove_index :ticket_shares, :expires_at if index_exists?(:ticket_shares, :expires_at)
    
    # Remove the expires_at column
    remove_column :ticket_shares, :expires_at, :datetime if column_exists?(:ticket_shares, :expires_at)
  end
end

