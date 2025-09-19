class CreateTicketShares < ActiveRecord::Migration[7.0]
  def change
    create_table :ticket_shares do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :shared_with, null: false, foreign_key: { to_table: :users }
      t.json :permissions, null: false, default: []
      t.text :message
      t.timestamps
    end

    add_index :ticket_shares, [:ticket_id, :shared_with_id], unique: true
    add_index :ticket_shares, :permissions, using: :gin
  end
end



