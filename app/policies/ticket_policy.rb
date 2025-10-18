# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketPolicy < ApplicationPolicy

  def show?
    access?('read')
  end

  def create?
    return false if !ensure_group?

    access?('create')
  end

  def update?
    access?('change')
  end

  def destroy?
    return true if user.permissions?('admin')

    # This might look like a bug is actually just defining
    # what exception is being raised and shown to the user.
    return false if !access?('delete')

    not_authorized('admin permission required')
  end

  def full?
    access?('full')
  end

  def ensure_group?
    return true if record.group_id

    not_authorized Exceptions::UnprocessableEntity.new __("The required value 'group_id' is missing.")
  end

  def follow_up?
    # This method is used to check if a follow-up is possible (mostly based on the configuration).
    # Agents are always allowed to reopen tickets, configuration does not matter.

    return update? if Ticket::StateType.lookup(id: record.state.state_type_id).name != 'closed' # check if the ticket state is already closed
    return true if agent_update_access?

    # Check follow_up_possible configuration, based on the group.
    return true if follow_up_possible? && update?

    not_authorized Exceptions::UnprocessableEntity.new __('Cannot follow-up on a closed ticket. Please create a new ticket.')
  end

  def agent_read_access?
    agent_access?('read')
  end

  def agent_update_access?
    agent_access?('change')
  end

  def agent_create_access?
    agent_access?('create')
  end

  def create_mentions?
    return true if agent_read_access?

    not_authorized __('You have insufficient permissions to mention other users.')
  end

  private

  def follow_up_possible?
    case record.group.follow_up_possible
    when 'yes'
      true
    when 'new_ticket_after_certain_time'
      record.reopen_after_certain_time?
    when 'new_ticket'
      false
    end
  end

  def access?(access)
    # Check approval access FIRST (approvers get full access)
    approval_decision = approval_access?(access)
    return approval_decision unless approval_decision.nil?
    
    # Check CC access
    cc_decision = cc_access?(access)
    return cc_decision unless cc_decision.nil?
    
    share_decision = share_access?(access)
    return share_decision unless share_decision.nil?

    return true if agent_access?(access)

    customer_access?
  end

  def agent_access?(access)
    return false if !user.permissions?('ticket.agent')

    user.group_access?(record.group.id, access)
  end

  # Allow access via Ticket::Approval for approvers.
  # Only agents and admins can be approvers (standard Zammad requirement).
  # Approvers get full access to tickets they need to approve.
  # This prevents the need to create shares that give access to entire groups.
  def approval_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent') # Only agents can be approvers
    
    # Check if user is an approver for this ticket (any status)
    is_approver = record.approvals.exists?(approver_id: user.id)
    return nil unless is_approver
    
    # Approvers get full access (read, comment, edit) for tickets they need to approve
    case access.to_s
    when 'read', 'change', 'create', 'full'
      true
    else
      nil
    end
  end

  # Allow access via Ticket::Cc for CC'd users.
  # Both agents and customers can be CC'd on tickets.
  # CC'd users get access based on their permissions (read, comment, or full).
  def cc_access?(access)
    return nil unless user
    
    # Check if user is CC'd on this ticket
    cc = record.ccs.find_by(user_id: user.id)
    return nil unless cc

    # Map access to CC permissions
    case access.to_s
    when 'read'
      cc.read_access? ? true : nil
    when 'create', 'change'
      if user.permissions?('ticket.agent')
        cc.full_access? ? true : nil
      else
        cc.comment_access? ? true : nil
      end
    when 'full'
      cc.full_access? ? true : nil
    else
      nil
    end
  end

  # Allow access via Ticket::Share for the current user.
  # Maps Zammad policy accesses to share permissions:
  # - 'read'  -> read/comment/edit
  # - 'change'-> edit
  # - 'create'-> comment (e.g., add notes)
  def share_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent') # Only agents can access shared tickets

    share_group_ids = Ticket::Share.active_current.where(ticket_id: record.id).pluck(:group_id)
    return nil if share_group_ids.empty?

    # Check if user has ANY permission level in the shared groups (read, change, or full)
    user_group_ids_read = Array(user.group_ids_access('read'))
    user_group_ids_change = Array(user.group_ids_access('change'))
    user_group_ids_full = Array(user.group_ids_access('full'))
    
    # Combine all group IDs where user has any permission
    user_group_ids = (user_group_ids_read + user_group_ids_change + user_group_ids_full).uniq
    return nil if (share_group_ids & user_group_ids).blank?

    # Users with share access get full permissions
    case access.to_s
    when 'read', 'change', 'create', 'full'
      true
    else
      nil
    end
  end

  def customer_access?
    return false if !user.permissions?('ticket.customer')
    return customer_field_scope if customer?

    shared_organization?
  end

  def customer?
    record.customer_id == user.id
  end

  def shared_organization?
    return false if record.organization_id.blank?
    return false if user.organization_id.blank?
    return false if !user.organization_id?(record.organization_id)
    return false if !record.organization.shared?

    customer_field_scope
  end

  def customer_field_scope
    @customer_field_scope ||= ApplicationPolicy::FieldScope.new(deny: %i[time_unit time_units_per_type checklist referencing_checklist_tickets])
  end
end

