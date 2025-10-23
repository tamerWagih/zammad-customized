# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class CreateTicketCcs < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:ticket_ccs)

    create_table :ticket_ccs do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :permissions, array: true, default: ['read', 'comment']
      t.string :message, limit: 500
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.references :updated_by, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :ticket_ccs, [:ticket_id, :user_id], unique: true, name: 'index_ticket_ccs_on_ticket_id_and_user_id'
    add_index :ticket_ccs, :user_id
    add_index :ticket_ccs, :created_at
  end

  def down
    drop_table :ticket_ccs if table_exists?(:ticket_ccs)
  end
end

