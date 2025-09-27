class CreateTicketApprovals < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_approvals do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :approver, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'pending'
      t.text :message
      t.timestamps
    end

    add_index :ticket_approvals, [:ticket_id, :approver_id], unique: true
    add_index :ticket_approvals, :status
  end
end




