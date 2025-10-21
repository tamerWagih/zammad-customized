# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Controller for providing safe attribute lists for custom filters
# This replaces the need for agents to access ObjectManagerAttributesController
class CustomFilterAttributesController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # GET /api/v1/custom_filter_attributes
  def index
    # Return safe attributes based on user role
    attributes = build_safe_attributes_for_user

    render json: attributes
  end

  private

  def build_safe_attributes_for_user
    # Provide ALL ticket attributes for agents and admins (same functionality)
    # The only difference is ticket visibility - agents see only tickets they have permission to access
    # This is enforced by Ticket.selector2sql(current_user: ...) in the backend
    
    # For customers, provide a limited set of attributes
    if !current_user.permissions?('ticket.agent') && !current_user.permissions?('admin.overview')
      return build_customer_attributes
    end
    
    # Full attribute list for agents and admins
    base_attributes = [
      # Core ticket attributes (same as App.Ticket.configure_attributes)
      { name: 'number', display: 'Number', tag: 'input', type: 'text', searchable: true },
      { name: 'title', display: 'Title', tag: 'input', type: 'text', searchable: true },
      { name: 'customer_id', display: 'Customer', tag: 'select', relation: 'User', searchable: true },
      { name: 'organization_id', display: 'Organization', tag: 'select', relation: 'Organization', searchable: true },
      { name: 'group_id', display: 'Group', tag: 'tree_select', relation: 'Group', searchable: true },
      { name: 'owner_id', display: 'Owner', tag: 'select', relation: 'User', searchable: true },
      { name: 'state_id', display: 'State', tag: 'select', relation: 'TicketState', searchable: true },
      { name: 'pending_time', display: 'Pending till', tag: 'datetime', searchable: true },
      { name: 'priority_id', display: 'Priority', tag: 'select', relation: 'TicketPriority', searchable: true },
      { name: 'escalation_at', display: 'Escalation at', tag: 'datetime', searchable: true },
      { name: 'first_response_escalation_at', display: 'Escalation at (First Response Time)', tag: 'datetime', searchable: true },
      { name: 'update_escalation_at', display: 'Escalation at (Update Time)', tag: 'datetime', searchable: true },
      { name: 'close_escalation_at', display: 'Escalation at (Close Time)', tag: 'datetime', searchable: true },
      { name: 'last_contact_at', display: 'Last contact', tag: 'datetime', searchable: true },
      { name: 'last_contact_agent_at', display: 'Last contact (agent)', tag: 'datetime', searchable: true },
      { name: 'last_contact_customer_at', display: 'Last contact (customer)', tag: 'datetime', searchable: true },
      { name: 'first_response_at', display: 'First response', tag: 'datetime', searchable: true },
      { name: 'close_at', display: 'Closing time', tag: 'datetime', searchable: true },
      { name: 'last_close_at', display: 'Last closing time', tag: 'datetime', searchable: true },
      { name: 'created_by_id', display: 'Created by', tag: 'select', relation: 'User', searchable: true },
      { name: 'created_at', display: 'Created at', tag: 'datetime', searchable: true },
      { name: 'updated_by_id', display: 'Updated by', tag: 'select', relation: 'User', searchable: true },
      { name: 'updated_at', display: 'Updated at', tag: 'datetime', searchable: true },
      { 
        name: 'article', 
        display: 'Article', 
        tag: 'ticket_article',
        searchable: true
      },
      { name: 'tags', display: 'Tags', tag: 'tag', searchable: true },
      { name: 'mention_user_ids', display: 'Subscribe', tag: 'select', relation: 'User', searchable: true },
    ]

    # Add custom filter specific attributes (shared with me, approval status, etc.)
    custom_attributes = [
      { 
        name: 'shared_with_me', 
        display: 'Shared with Me', 
        tag: 'select', 
        type: 'boolean', 
        searchable: true, 
        operator: ['is', 'is not'], 
        options: [
          { value: true, name: 'Yes' },
          { value: false, name: 'No' }
        ] 
      },
      { 
        name: 'approval_status', 
        display: 'Approval Status', 
        tag: 'select', 
        type: 'select', 
        searchable: true, 
        operator: ['is', 'is not'], 
        options: [
          { value: 'pending', name: 'Pending' },
          { value: 'approved', name: 'Approved' },
          { value: 'rejected', name: 'Rejected' }
        ] 
      },
      { 
        name: 'requested_for_approval', 
        display: 'Requested for Approval', 
        tag: 'select', 
        type: 'boolean', 
        searchable: true, 
        operator: ['is', 'is not'], 
        options: [
          { value: true, name: 'Yes' },
          { value: false, name: 'No' }
        ] 
      },
    ]

    base_attributes + custom_attributes
  end

  def build_customer_attributes
    # Limited attributes for customers
    [
      { name: 'number', display: 'Number', tag: 'input', type: 'text', searchable: true },
      { name: 'title', display: 'Title', tag: 'input', type: 'text', searchable: true },
      { name: 'state_id', display: 'State', tag: 'select', relation: 'TicketState', searchable: true },
      { name: 'priority_id', display: 'Priority', tag: 'select', relation: 'TicketPriority', searchable: true },
      { name: 'created_at', display: 'Created at', tag: 'datetime', searchable: true },
      { name: 'updated_at', display: 'Updated at', tag: 'datetime', searchable: true },
    ]
  end
end


