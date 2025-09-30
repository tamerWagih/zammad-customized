# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class ConvertApprovalStatesToTags < ActiveRecord::Migration[7.2]
  def up
    # First, add tags to tickets that are currently in approved/rejected states
    execute <<-SQL
      UPDATE tickets 
      SET tags = CASE 
        WHEN state_id = 7 THEN COALESCE(tags, '') || CASE WHEN tags IS NULL OR tags = '' THEN 'approved' ELSE ',approved' END
        WHEN state_id = 8 THEN COALESCE(tags, '') || CASE WHEN tags IS NULL OR tags = '' THEN 'rejected' ELSE ',rejected' END
        ELSE tags
      END
      WHERE state_id IN (7, 8);
    SQL

    # Update overviews to use tag-based filtering instead of state-based
    execute <<-SQL
      UPDATE overviews 
      SET condition = '{"ticket.tags": {"operator": "contains", "value": "approved"}}'
      WHERE id = 100 AND name = 'Approved Tickets';
    SQL

    execute <<-SQL
      UPDATE overviews 
      SET condition = '{"ticket.tags": {"operator": "contains", "value": "rejected"}}'
      WHERE id = 101 AND name = 'Rejected Tickets';
    SQL

    # Remove the approval/rejection states
    execute <<-SQL
      DELETE FROM ticket_states WHERE name IN ('approved', 'rejected');
    SQL
  end

  def down
    # Recreate the approval/rejection states
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

    # Revert overviews to state-based filtering
    execute <<-SQL
      UPDATE overviews 
      SET condition = '{"ticket.state_id": {"operator": "is", "value": [7]}}'
      WHERE id = 100 AND name = 'Approved Tickets';
    SQL

    execute <<-SQL
      UPDATE overviews 
      SET condition = '{"ticket.state_id": {"operator": "is", "value": [8]}}'
      WHERE id = 101 AND name = 'Rejected Tickets';
    SQL

    # Remove tags and set states back
    execute <<-SQL
      UPDATE tickets 
      SET state_id = 7, tags = TRIM(BOTH ',' FROM REPLACE(REPLACE(tags, ',approved', ''), 'approved', ''))
      WHERE tags LIKE '%approved%';
    SQL

    execute <<-SQL
      UPDATE tickets 
      SET state_id = 8, tags = TRIM(BOTH ',' FROM REPLACE(REPLACE(tags, ',rejected', ''), 'rejected', ''))
      WHERE tags LIKE '%rejected%';
    SQL
  end
end
