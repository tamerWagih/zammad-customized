# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TransitionTicketSharesToGroups < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  class MigrationTicketShare < ActiveRecord::Base
    self.table_name = "ticket_shares"
  end

  def up
    if index_exists?(:ticket_shares, [:ticket_id, :shared_with_id])
      remove_index :ticket_shares, column: [:ticket_id, :shared_with_id]
    end

    if index_exists?(:ticket_shares, name: "index_ticket_shares_on_ticket_and_shared_with_active")
      remove_index :ticket_shares, name: "index_ticket_shares_on_ticket_and_shared_with_active"
    end

    add_reference :ticket_shares, :group, foreign_key: true

    MigrationTicketShare.reset_column_information
    MigrationTicketShare.delete_all

    change_column_null :ticket_shares, :group_id, false

    remove_column :ticket_shares, :shared_with_id

    change_column_default :ticket_shares, :permissions, ["full"]
    MigrationTicketShare.reset_column_information
    MigrationTicketShare.update_all(permissions: ["full"])

    add_index :ticket_shares,
              [:ticket_id, :group_id],
              unique: true,
              where: "status = 'active'",
              name: "index_ticket_shares_on_ticket_and_group_active",
              algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "TransitionTicketSharesToGroups cannot be reversed"
  end
end


