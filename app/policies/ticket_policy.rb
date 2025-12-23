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
      return cc_decision
    end

    # Check approval access (approvers get full access)
    approval_decision = approval_access?(access)
    unless approval_decision.nil?
      return approval_decision
    end

    # Check if user is the ticket creator (view + comment access)
    creator_decision = creator_access?(access)
    unless creator_decision.nil?
      return creator_decision
    end

    share_decision = share_access?(access)
    unless share_decision.nil?
      return share_decision
    end

    group_decision = agent_access?(access)
    if group_decision
      return true
    end

    customer_decision = customer_access?
    customer_decision
  end

  def agent_access?(access)
    return false if !user.permissions?('ticket.agent')

    user.group_access?(record.group.id, access)
  end

  # Allow access via Ticket::Cc for CC'd users.
  # Agents get full access, customers get read + comment access.
  # Uses Auth::RequestCache to avoid repeated DB queries per request.
  def cc_access?(access)
    return nil unless user

    # Cache CC record lookup per ticket+user per request
    cc_record = cc_record_cached
    return nil if cc_record.nil?

    # Check permissions based on CC record
    # Permission mapping:
    # - 'read' = view ticket → requires read_access or full_access
    # - 'create' = add comments/articles → requires comment_access or full_access
    # - 'change' = edit ticket attributes → requires full_access ONLY
    # - 'full' = full access → requires full_access
    case access.to_s
    when 'read'
      cc_record.read_access?
    when 'create'
      # Comment access allows adding articles/comments
      cc_record.full_access? || cc_record.comment_access?
    when 'change', 'full'
      # CRITICAL: Only full_access can edit ticket attributes
      # comment_access should NOT grant 'change' permission
      cc_record.full_access?
    else
      nil
    end
  end

  # Cache CC record lookup per ticket+user per request
  # Uses :not_found sentinel to properly cache nil results (Auth::RequestCache doesn't cache nil)
  def cc_record_cached
    cache_key = "TicketPolicy/cc_record/#{record.id}/#{user.id}"
    cached = Auth::RequestCache.fetch_value(cache_key) do
      record.ccs.find_by(user_id: user.id) || :not_found
    end
    cached == :not_found ? nil : cached
  end

  # Allow access via Ticket::Approval.
  # Only agents and admins can be approvers or requesters (standard Zammad requirement).
  # Both requester and approver get full access.
  # Uses Auth::RequestCache to avoid repeated DB queries per request.
  def approval_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent') # Only agents can be approvers/requesters
    
    # Cache approval role check per ticket+user per request
    approval_role = approval_role_cached
    return nil unless approval_role
    
    # Both requester and approver get full access (read, comment, edit)
    case access.to_s
    when 'read', 'change', 'create', 'full'
      true
    else
      nil
    end
  end

  # Cache approval role (requester/approver) lookup per ticket+user per request
  # Returns :requester, :approver, or nil
  # Uses :not_found sentinel to properly cache nil results (Auth::RequestCache doesn't cache nil)
  def approval_role_cached
    cache_key = "TicketPolicy/approval_role/#{record.id}/#{user.id}"
    cached = Auth::RequestCache.fetch_value(cache_key) do
      is_requester = record.approvals.exists?(requester_id: user.id)
      is_approver = record.approvals.exists?(approver_id: user.id)
      
      if is_requester
        :requester
      elsif is_approver
        :approver
      else
        :not_found
      end
    end
    cached == :not_found ? nil : cached
  end

  # Allow ticket creator (created_by) to view and comment on their tickets
  # even if the ticket is in a different group.
  # Uses Auth::RequestCache to avoid repeated DB queries per request.
  def creator_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent')
    
    # Check if user created this ticket
    return nil unless record.created_by_id == user.id
    
    # CRITICAL: Check if creator is a DIRECT MEMBER of ticket's group (not via role)
    # Cache user group IDs per request
    user_group_ids = user_group_ids_cached
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
    # → Grant view + comment, but let other checks handle change/full
    case access.to_s
    when 'read', 'create'
      true  # Grant read and create (view + comment)
    else
      nil   # Don't handle change/full - let group/other access handle it
    end
  end

  # Allow access via Ticket::Share for the current user.
  # Sharer from different group: full access
  # Sharer from SAME group: full access via agent_access?
  # Receiver from SAME group: full access via agent_access?
  # Receiver from DIFFERENT group: comment-only access.
  # Uses Auth::RequestCache to avoid repeated DB queries per request.
  def share_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent') # Only agents can access shared tickets

    # Cache share role check per ticket+user per request
    share_info = share_info_cached
    user_is_sharer = share_info[:is_sharer]
    user_is_receiver = share_info[:is_receiver]

    return nil unless user_is_sharer || user_is_receiver

    # CRITICAL: Check if user is a DIRECT MEMBER of ticket's group (not via role)
    # If user IS a direct member, let agent_access? handle it (standard group permissions)
    # If user is NOT a direct member but has share → use share-only permissions
    # This prevents role-based permissions from overriding share restrictions
    user_group_ids = user_group_ids_cached
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

  # Cache share info (sharer/receiver status) per ticket+user per request
  def share_info_cached
    Auth::RequestCache.fetch_value("TicketPolicy/share_info/#{record.id}/#{user.id}") do
      user_group_ids = user_group_ids_cached
      
      # Check if user is the sharer (person who created the share)
      is_sharer = record.shares.active_current.exists?(shared_by_id: user.id)
      
      # Check if user is a receiver (member of a group that ticket is shared with)
      active_shares = record.shares.active_current
      is_receiver = active_shares.any? { |s| user_group_ids.include?(s.group_id) }
      
      { is_sharer: is_sharer, is_receiver: is_receiver }
    end
  end

  # Cache user group IDs per request (used by creator_access? and share_access?)
  def user_group_ids_cached
    Auth::RequestCache.fetch_value("TicketPolicy/user_group_ids/#{user.id}") do
      user.groups.pluck(:id)
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

