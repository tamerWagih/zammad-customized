# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class UpdateApprovedRejectedOverviewColumns < ActiveRecord::Migration[7.2]
  def up
    # Update "Approved Tickets" overview to have proper columns like Open Tickets
    execute <<-SQL
      UPDATE overviews 
      SET 
        "order" = '{"by": "created_at", "direction": "ASC"}',
        view = '{"d": ["title", "customer", "group", "state", "owner", "created_at"], "s": ["title", "customer", "group", "state", "owner", "created_at"], "m": ["number", "title", "customer", "group", "state", "owner", "created_at"], "view_mode_default": "s"}'
      WHERE name = 'Approved Tickets';
    SQL

    # Update "Rejected Tickets" overview to have proper columns like Open Tickets
    execute <<-SQL
      UPDATE overviews 
      SET 
        "order" = '{"by": "created_at", "direction": "ASC"}',
        view = '{"d": ["title", "customer", "group", "state", "owner", "created_at"], "s": ["title", "customer", "group", "state", "owner", "created_at"], "m": ["number", "title", "customer", "group", "state", "owner", "created_at"], "view_mode_default": "s"}'
      WHERE name = 'Rejected Tickets';
    SQL
  end

  def down
    # Revert to simple view structure
    execute <<-SQL
      UPDATE overviews 
      SET 
        "order" = 'created_at DESC',
        view = 's'
      WHERE name IN ('Approved Tickets', 'Rejected Tickets');
    SQL
  end
end
