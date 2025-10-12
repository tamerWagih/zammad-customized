class AdjustTicketShareAndApprovalIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    if index_exists?(:ticket_shares, [:ticket_id, :shared_with_id])
      remove_index :ticket_shares, column: [:ticket_id, :shared_with_id]
    end

    add_index :ticket_shares,
              [:ticket_id, :shared_with_id],
              unique: true,
              where: "status = 'active'",
              name:  'index_ticket_shares_on_ticket_and_shared_with_active',
              algorithm: :concurrently

    if index_exists?(:ticket_approvals, [:ticket_id, :approver_id])
      remove_index :ticket_approvals, column: [:ticket_id, :approver_id]
    end

    add_index :ticket_approvals,
              [:ticket_id, :approver_id],
              unique: true,
              where: "status = 'pending'",
              name:  'index_ticket_approvals_on_ticket_and_approver_pending',
              algorithm: :concurrently
  end

  def down
    if index_exists?(:ticket_shares, name: 'index_ticket_shares_on_ticket_and_shared_with_active')
      remove_index :ticket_shares, name: 'index_ticket_shares_on_ticket_and_shared_with_active'
    end

    add_index :ticket_shares,
              [:ticket_id, :shared_with_id],
              unique: true,
              algorithm: :concurrently

    if index_exists?(:ticket_approvals, name: 'index_ticket_approvals_on_ticket_and_approver_pending')
      remove_index :ticket_approvals, name: 'index_ticket_approvals_on_ticket_and_approver_pending'
    end

    add_index :ticket_approvals,
              [:ticket_id, :approver_id],
              unique: true,
              algorithm: :concurrently
  end
end
