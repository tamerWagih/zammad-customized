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

    # For adding comments/articles, check 'create' permission instead of 'change'
    # This allows users with comment-only share access to add comments
    can_create = access?('create')
    return true if can_create

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
    # Check CC access FIRST (CC'd users get access)
    cc_decision = cc_access?(access)
    unless cc_decision.nil?
      Rails.logger.info "[ACCESS] Ticket ##{record.id}, User ##{user&.id}, #{access}: STOPPED at CC (#{cc_decision})"
      return cc_decision
    end

    # Check approval access (approvers get full access)
    approval_decision = approval_access?(access)
    unless approval_decision.nil?
      Rails.logger.info "[ACCESS] Ticket ##{record.id}, User ##{user&.id}, #{access}: STOPPED at APPROVAL (#{approval_decision})"
      return approval_decision
    end

    # Check if user is the ticket creator (view + comment access)
    creator_decision = creator_access?(access)
    unless creator_decision.nil?
      Rails.logger.info "[ACCESS] Ticket ##{record.id}, User ##{user&.id}, #{access}: STOPPED at CREATOR (#{creator_decision})"
      return creator_decision
    end

    share_decision = share_access?(access)
    unless share_decision.nil?
      Rails.logger.info "[ACCESS] Ticket ##{record.id}, User ##{user&.id}, #{access}: STOPPED at SHARE (#{share_decision})"
      return share_decision
    end

    group_decision = agent_access?(access)
    if group_decision
      Rails.logger.info "[ACCESS] Ticket ##{record.id}, User ##{user&.id}, #{access}: STOPPED at GROUP (true)"
      return true
    end

    customer_decision = customer_access?
    Rails.logger.info "[ACCESS] Ticket ##{record.id}, User ##{user&.id}, #{access}: STOPPED at CUSTOMER (#{customer_decision})"
    customer_decision
  end

  def agent_access?(access)
    return false if !user.permissions?('ticket.agent')

    user.group_access?(record.group.id, access)
  end

  # Allow access via Ticket::Cc for CC'd users.
  # Agents get full access, customers get read + comment access.
  def cc_access?(access)
    return nil unless user

    # Check if user is CC'd on this ticket
    cc_record = record.ccs.find_by(user_id: user.id)
    return nil if cc_record.nil?

    # Check permissions based on CC record
    case access.to_s
    when 'read'
      cc_record.read_access?
    when 'change', 'create'
      # CRITICAL: Allow if user has full access OR comment access
      # This allows both agents (full) and customers (comment) to update tickets
      cc_record.full_access? || cc_record.comment_access?
    when 'full'
      cc_record.full_access?
    else
      nil
    end
  end

  # Allow access via Ticket::Approval.
  # Only agents and admins can be approvers or requesters (standard Zammad requirement).
  # Both requester and approver get full access
  def approval_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent') # Only agents can be approvers/requesters
    
    # Check if user is a requester (creator) or approver for this ticket
    is_requester = record.approvals.exists?(requester_id: user.id)
    is_approver = record.approvals.exists?(approver_id: user.id)
    
    return nil unless is_requester || is_approver
    
    # Both requester and approver get full access (read, comment, edit)
    case access.to_s
    when 'read', 'change', 'create', 'full'
      true
    else
      nil
    end
  end

  # Allow ticket creator (created_by) to view and comment on their tickets
  # even if the ticket is in a different group
  def creator_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent')
    
    # Check if user created this ticket
    return nil unless record.created_by_id == user.id
    
    # CRITICAL: Check if creator is a DIRECT MEMBER of ticket's group (not via role)
    user_group_ids = user.groups.pluck(:id)
    is_direct_member = user_group_ids.include?(record.group_id)
    
    # If creator IS a direct member, check if they have the requested permission
    # If they do, let agent_access? handle it (for full access via group)
    # If they DON'T (e.g., have 'create' but not 'read'), grant creator access
    if is_direct_member
      has_permission = user.group_access?(record.group_id, access.to_s)
      return nil if has_permission  # User has permission via group, let agent_access handle it
      # User is direct member but lacks this permission → fall through to grant creator access
    end
    
    # Creator either:
    # 1. NOT direct member of ticket's group, OR
    # 2. IS direct member but lacks the requested permission
    # → Grant ONLY view + comment (NOT change/full)
    # This allows agents to create tickets for any department and still view/comment on them
    case access.to_s
    when 'read', 'create'
      true
    when 'change', 'full'
      false
    else
      nil
    end
  end

  # Allow access via Ticket::Share for the current user.
  # Sharer from different group: full access
  # Sharer from SAME group: full access via agent_access?
  # Receiver from SAME group: full access via agent_access?
  # Receiver from DIFFERENT group: comment-only access
  def share_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent') # Only agents can access shared tickets

    # Check if user is the sharer (person who created the share)
    user_is_sharer = record.shares.active_current.exists?(shared_by_id: user.id)
    
    # Check if user is a receiver (member of a group that ticket is shared with)
    active_shares = Ticket::Share.active_current.where(ticket_id: record.id)
    user_group_ids = user.groups.pluck(:id)
    receiver_shares = active_shares.select { |s| user_group_ids.include?(s.group_id) }
    user_is_receiver = receiver_shares.present?

    return nil unless user_is_sharer || user_is_receiver

    # CRITICAL: Check if user is a DIRECT MEMBER of ticket's group (not via role)
    # If user IS a direct member, let agent_access? handle it (standard group permissions)
    # If user is NOT a direct member but has share → use share-only permissions
    # This prevents role-based permissions from overriding share restrictions
    is_direct_member = user_group_ids.include?(record.group_id)
    return nil if is_direct_member
    
    # User does NOT have requested access to ticket's group: handle via share logic
    # Sharer (no access to ticket's group) → Full access
    if user_is_sharer
      return true if %w[read change create full].include?(access.to_s)
    end
    
    # Receiver (no access to ticket's group) → Comment-only access
    case access.to_s
    when 'read', 'create'
      true
    when 'change', 'full'
      false
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

