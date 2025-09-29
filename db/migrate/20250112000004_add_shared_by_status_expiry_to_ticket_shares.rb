class AddSharedByStatusExpiryToTicketShares < ActiveRecord::Migration[7.2]
  def change
    change_table :ticket_shares do |t|
      t.references :shared_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'active'
      t.datetime :expires_at
    end

    add_index :ticket_shares, :status
    add_index :ticket_shares, :expires_at
  end
end


