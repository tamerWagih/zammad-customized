# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class CreateTicketCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :ticket_ccs do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :permissions, array: true, default: []
      t.text :message
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.references :updated_by, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :ticket_ccs, [:ticket_id, :user_id], unique: true
    add_index :ticket_ccs, :user_id
    add_index :ticket_ccs, :created_at
  end
end
