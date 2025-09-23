class AddRequesterPriorityToTicketApprovals < ActiveRecord::Migration[7.0]
  def change
    change_table :ticket_approvals do |t|
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.string :priority, null: false, default: 'normal'
    end

    add_index :ticket_approvals, :priority
  end
end


