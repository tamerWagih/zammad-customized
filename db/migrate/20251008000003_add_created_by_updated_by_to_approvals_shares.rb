# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddCreatedByUpdatedByToApprovalsShares < ActiveRecord::Migration[7.2]
  def change
    # Add created_by_id and updated_by_id to ticket_approvals
    add_reference :ticket_approvals, :created_by, null: true, foreign_key: { to_table: :users }
    add_reference :ticket_approvals, :updated_by, null: true, foreign_key: { to_table: :users }
    
    # Add created_by_id and updated_by_id to ticket_shares
    add_reference :ticket_shares, :created_by, null: true, foreign_key: { to_table: :users }
    add_reference :ticket_shares, :updated_by, null: true, foreign_key: { to_table: :users }
  end
end
