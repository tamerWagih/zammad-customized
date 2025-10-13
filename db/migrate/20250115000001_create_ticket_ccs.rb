# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class CreateTicketCcs < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_ccs do |t|
      t.references :ticket, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      t.string :permissions, array: true, default: []
      t.string :message, limit: 500
      t.timestamps
    end
    
    # Ensure unique CC per user per ticket
    add_index :ticket_ccs, [:ticket_id, :user_id], unique: true, name: 'index_ticket_ccs_on_ticket_id_and_user_id'
  end
end

