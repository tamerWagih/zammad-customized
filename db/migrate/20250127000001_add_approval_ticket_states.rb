# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddApprovalTicketStates < ActiveRecord::Migration[7.2]
      def up
        # Create ticket states for approved and rejected using direct SQL
        # Use existing 'closed' state type (id: 5) so they appear in state dropdowns
        execute <<-SQL
          INSERT INTO ticket_states (id, name, state_type_id, ignore_escalation, created_by_id, updated_by_id, created_at, updated_at)
          VALUES (7, 'approved', 5, true, 1, 1, NOW(), NOW())
          ON CONFLICT (id) DO NOTHING;
        SQL
        
        execute <<-SQL
          INSERT INTO ticket_states (id, name, state_type_id, ignore_escalation, created_by_id, updated_by_id, created_at, updated_at)
          VALUES (8, 'rejected', 5, true, 1, 1, NOW(), NOW())
          ON CONFLICT (id) DO NOTHING;
        SQL
      end
  
  def down
    # Remove the created states using direct SQL
    execute <<-SQL
      DELETE FROM ticket_states WHERE name IN ('approved', 'rejected');
    SQL
  end
end
