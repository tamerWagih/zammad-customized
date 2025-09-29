# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AddApprovedRejectedOverviews < ActiveRecord::Migration[7.2]
  def up
    # Get agent role for the overview
    agent_role = Role.find_by(name: 'Agent')
    return unless agent_role

    # Create "Approved Tickets" overview
    execute <<-SQL
      INSERT INTO overviews (id, name, link, prio, condition, "order", view, updated_by_id, created_by_id, created_at, updated_at)
      VALUES (
        100,
        'Approved Tickets',
        'approved_tickets',
        1060,
        '{"ticket.state_id": {"operator": "is", "value": [7]}}',
        '{"by": "created_at", "direction": "ASC"}',
        '{"d": ["title", "customer", "group", "state", "owner", "created_at"], "s": ["title", "customer", "group", "state", "owner", "created_at"], "m": ["number", "title", "customer", "group", "state", "owner", "created_at"], "view_mode_default": "s"}',
        1,
        1,
        NOW(),
        NOW()
      );
    SQL

    # Assign agent role to approved tickets overview
    execute <<-SQL
      INSERT INTO overviews_roles (overview_id, role_id)
      VALUES (100, #{agent_role.id});
    SQL

    # Create "Rejected Tickets" overview
    execute <<-SQL
      INSERT INTO overviews (id, name, link, prio, condition, "order", view, updated_by_id, created_by_id, created_at, updated_at)
      VALUES (
        101,
        'Rejected Tickets',
        'rejected_tickets',
        1070,
        '{"ticket.state_id": {"operator": "is", "value": [8]}}',
        '{"by": "created_at", "direction": "ASC"}',
        '{"d": ["title", "customer", "group", "state", "owner", "created_at"], "s": ["title", "customer", "group", "state", "owner", "created_at"], "m": ["number", "title", "customer", "group", "state", "owner", "created_at"], "view_mode_default": "s"}',
        1,
        1,
        NOW(),
        NOW()
      );
    SQL

    # Assign agent role to rejected tickets overview
    execute <<-SQL
      INSERT INTO overviews_roles (overview_id, role_id)
      VALUES (101, #{agent_role.id});
    SQL
  end

  def down
    # Remove the created overviews
    execute <<-SQL
      DELETE FROM overviews_roles WHERE overview_id IN (100, 101);
    SQL

    execute <<-SQL
      DELETE FROM overviews WHERE id IN (100, 101);
    SQL
  end
end
