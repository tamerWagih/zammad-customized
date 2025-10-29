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
    return cc_decision unless cc_decision.nil?

    # Check approval access (approvers get full access)
    approval_decision = approval_access?(access)
    return approval_decision unless approval_decision.nil?

    share_decision = share_access?(access)
    return share_decision unless share_decision.nil?

    return true if agent_access?(access)

    customer_access?
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
  # Follow same pattern as share: creator gets full access, approver gets full access (for approval actions)
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

  # Allow access via Ticket::Share for the current user.
  # Follow the same pattern as approval_access?: creator gets full access, receivers get comment-only
  # - 'read'  -> view ticket
  # - 'create'-> add notes/comments
  # - 'change'-> edit ticket fields (sharer only)
  # - 'full'  -> full access (sharer only)
  def share_access?(access)
    return nil unless user
    return nil unless user.permissions?('ticket.agent') # Only agents can access shared tickets

    # Check if user is the sharer (creator gets full access like approval creator)
    user_is_sharer = record.shares.active_current.exists?(shared_by_id: user.id)
    
    # Check if user is a receiver (member of shared group)
    share_group_ids = Ticket::Share.active_current.where(ticket_id: record.id).pluck(:group_id)
    user_group_ids = Array(user.group_ids_access('read'))
    user_is_receiver = share_group_ids.present? && (share_group_ids & user_group_ids).present?

    return nil unless user_is_sharer || user_is_receiver

    # Map access based on role (like approval: creator = full, receiver = comment)
    case access.to_s
    when 'read', 'create'  # read = view, create = add notes/comments
      true  # Both sharer and receivers can view and comment
    when 'change', 'full'  # change = edit fields, full = full access
      user_is_sharer  # Only sharer can edit ticket fields
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

