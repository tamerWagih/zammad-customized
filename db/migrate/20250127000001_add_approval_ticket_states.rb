# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddApprovalTicketStates < ActiveRecord::Migration[6.1]
  def up
    # Create new ticket state types for approval workflow using direct SQL
    execute <<-SQL
      INSERT INTO ticket_state_types (id, name, created_at, updated_at) 
      VALUES (7, 'approved', NOW(), NOW())
      ON CONFLICT (id) DO NOTHING;
    SQL
    
    execute <<-SQL
      INSERT INTO ticket_state_types (id, name, created_at, updated_at) 
      VALUES (8, 'rejected', NOW(), NOW())
      ON CONFLICT (id) DO NOTHING;
    SQL
    
    # Create ticket states for approved and rejected using direct SQL
    execute <<-SQL
      INSERT INTO ticket_states (id, name, state_type_id, ignore_escalation, created_at, updated_at)
      VALUES (7, 'approved', 7, true, NOW(), NOW())
      ON CONFLICT (id) DO NOTHING;
    SQL
    
    execute <<-SQL
      INSERT INTO ticket_states (id, name, state_type_id, ignore_escalation, created_at, updated_at)
      VALUES (8, 'rejected', 8, true, NOW(), NOW())
      ON CONFLICT (id) DO NOTHING;
    SQL
  end
  
  def down
    # Remove the created states and state types using direct SQL
    execute <<-SQL
      DELETE FROM ticket_states WHERE name IN ('approved', 'rejected');
    SQL
    
    execute <<-SQL
      DELETE FROM ticket_state_types WHERE name IN ('approved', 'rejected');
    SQL
  end
end
