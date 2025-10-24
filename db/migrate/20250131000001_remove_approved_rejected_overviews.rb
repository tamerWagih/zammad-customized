# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/
#
# Remove Approved and Rejected Tickets overviews
# Users can now create these filters using dynamic filters instead
class RemoveApprovedRejectedOverviews < ActiveRecord::Migration[7.2]
  def up
    # Remove "Approved Tickets" overview (ID 100)
    execute "DELETE FROM overviews_roles WHERE overview_id = 100"
    execute "DELETE FROM overviews WHERE id = 100"
    
    # Remove "Rejected Tickets" overview (ID 101)
    execute "DELETE FROM overviews_roles WHERE overview_id = 101"
    execute "DELETE FROM overviews WHERE id = 101"
    
    Rails.logger.info "Removed Approved and Rejected Tickets overviews (IDs 100, 101)"
  end

  def down
    # Recreate the overviews if rollback is needed
    agent_role = Role.find_by(name: 'Agent')
    return unless agent_role

    # Recreate "Approved Tickets" overview
    execute <<-SQL
      INSERT INTO overviews (id, name, link, prio, condition, "order", view, updated_by_id, created_by_id, created_at, updated_at)
      VALUES (
        100,
        'Approved Tickets',
        'approved_tickets',
        1060,
        '{"ticket.tags": {"operator": "contains one", "value": "approved"}}',
        '{"by": "created_at", "direction": "ASC"}',
        '{"d": ["title", "customer", "group", "state", "owner", "created_at"], "s": ["title", "customer", "group", "state", "owner", "created_at"], "m": ["number", "title", "customer", "group", "state", "owner", "created_at"], "view_mode_default": "s"}',
        1,
        1,
        NOW(),
        NOW()
      );
    SQL

    execute "INSERT INTO overviews_roles (overview_id, role_id) VALUES (100, #{agent_role.id})"

    # Recreate "Rejected Tickets" overview
    execute <<-SQL
      INSERT INTO overviews (id, name, link, prio, condition, "order", view, updated_by_id, created_by_id, created_at, updated_at)
      VALUES (
        101,
        'Rejected Tickets',
        'rejected_tickets',
        1070,
        '{"ticket.tags": {"operator": "contains one", "value": "rejected"}}',
        '{"by": "created_at", "direction": "ASC"}',
        '{"d": ["title", "customer", "group", "state", "owner", "created_at"], "s": ["title", "customer", "group", "state", "owner", "created_at"], "m": ["number", "title", "customer", "group", "state", "owner", "created_at"], "view_mode_default": "s"}',
        1,
        1,
        NOW(),
        NOW()
      );
    SQL

    execute "INSERT INTO overviews_roles (overview_id, role_id) VALUES (101, #{agent_role.id})"
    
    Rails.logger.info "Recreated Approved and Rejected Tickets overviews (IDs 100, 101)"
  end
end

