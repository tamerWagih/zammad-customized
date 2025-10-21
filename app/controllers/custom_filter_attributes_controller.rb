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
    # Base ticket attributes that are safe for all agents/customers
    base_attributes = [
      { name: 'title', display: 'Title', tag: 'input', type: 'text', searchable: true },
      { name: 'number', display: 'Number', tag: 'input', type: 'text', searchable: true },
      { name: 'state_id', display: 'State', tag: 'select', relation: 'TicketState', searchable: true },
      { name: 'priority_id', display: 'Priority', tag: 'select', relation: 'TicketPriority', searchable: true },
      { name: 'group_id', display: 'Group', tag: 'select', relation: 'Group', searchable: true },
      { name: 'created_at', display: 'Created', tag: 'datetime', searchable: true },
      { name: 'updated_at', display: 'Updated', tag: 'datetime', searchable: true },
    ]

    # Add agent-specific attributes
    if current_user.permissions?('ticket.agent')
      base_attributes += [
        { name: 'owner_id', display: 'Owner', tag: 'select', relation: 'User', searchable: true },
        { name: 'customer_id', display: 'Customer', tag: 'select', relation: 'User', searchable: true },
        { name: 'organization_id', display: 'Organization', tag: 'select', relation: 'Organization', searchable: true },
        { 
          name: 'article', 
          display: 'Article', 
          tag: 'ticket_article',
          searchable: true,
          operators: ['contains', 'contains not']
        },
      ]
    end

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
end


