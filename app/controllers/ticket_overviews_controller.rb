# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class TicketOverviewsController < ApplicationController
  prepend_before_action :authentication_check

  # GET /api/v1/ticket_overview
  def data

    # get attributes to update
    attributes_to_change = Ticket::ScreenOptions.attributes_to_change(
      view:         'ticket_overview',
      screen:       'overview_bulk',
      current_user: current_user,
    )
    render json: attributes_to_change
  end

  # GET /api/v1/ticket_overviews
  def show

    # get navbar overview data
    if !params[:view]
      index_and_lists = Ticket::Overviews.index(current_user)
      indexes = []
      index_and_lists.each do |index|
        overview = Overview.lookup(id: index[:overview][:id])
        meta = {
          id:    overview.id,
          name:  overview.name,
          prio:  overview.prio,
          link:  overview.link,
          count: index[:count],
        }
        indexes.push meta
      end
      
      # Add custom filters
      custom_filters = current_user.preferences[:custom_filters] || []
      custom_filters.each do |filter|
        next unless filter['active']
        
        # Count tickets for this custom filter
        count = count_tickets_for_filter(filter)
        
        meta = {
          id:        filter['id'],
          name:      filter['name'],
          prio:      filter['prio'],
          link:      filter['link'],
          count:     count,
          is_custom: true,
        }
        indexes.push meta
      end
      
      render json: indexes
      return
    end

    # Check if this is a custom filter
    custom_filter = find_custom_filter_by_link(params[:view])
    
    if custom_filter
      # Handle custom filter view
      render_custom_filter_tickets(custom_filter)
      return
    end

    # Handle regular overview
    index_and_lists = Ticket::Overviews.index(current_user)

    assets = {}
    result = {}
    index_and_lists.each do |index|
      next if index[:overview][:view] != params[:view]

      overview = Overview.lookup(id: index[:overview][:id])
      assets = overview.assets(assets)
      index[:tickets].each do |ticket_meta|
        ticket = Ticket.lookup(id: ticket_meta[:id])
        assets = ticket.assets(assets)
      end
      result = index
    end

    render json: {
      assets: assets,
      index:  result,
    }
  end

  private

  def find_custom_filter_by_link(link)
    custom_filters = current_user.preferences[:custom_filters] || []
    custom_filters.find { |f| f['link'] == link && f['active'] }
  end

  def count_tickets_for_filter(filter)
    condition = filter['condition'] || {}
    
    # Use Ticket.selectors (like preview) to count with proper scopes
    ticket_count, _tickets = Ticket.selectors(
      condition,
      limit: 1,  # We only need count, not tickets
      current_user: current_user,
      custom_filter_context: true,
      access: 'full'
    )
    
    ticket_count || 0
  rescue => e
    Rails.logger.error "Error counting tickets for custom filter: #{e.message}"
    0
  end

  def render_custom_filter_tickets(filter)
    condition = filter['condition'] || {}
    order = filter['order'] || { 'by' => 'created_at', 'direction' => 'DESC' }
    view = filter['view'] || { 's' => ['number', 'title', 'customer', 'state', 'created_at'] }
    
    # Build the overview object first (so it's always available even on error)
    overview_data = {
      id:    filter['id'],
      name:  filter['name'],
      link:  filter['link'],
      view:  {
        s: view['s'] || ['number', 'title', 'customer', 'state', 'created_at']
      },
      order: {
        by:        order['by'] || 'created_at',
        direction: order['direction'] || 'DESC',
      },
      group_by: filter['group_by'] || '',
      group_direction: 'DESC',
      is_custom: true,
    }
    
    tickets = []
    assets = {}
    
    begin
      # Get tickets based on condition with custom filter context
      query, bind_params, tables = Ticket.selector2sql(
        condition, 
        current_user: current_user,
        custom_filter_context: true  # Enable custom filter attributes
      )
      
      if query.present?
        # Apply ordering
        order_by = order['by'] || 'created_at'
        order_direction = order['direction'] || 'DESC'
        
        # CRITICAL: Apply user permission scope first (like Zammad's overview system)
        # Use OverviewScope for standard conditions, ReadScope for mentions
        base_scope = if condition.key?('ticket.mention_user_ids')
                       TicketPolicy::ReadScope.new(current_user).resolve
                     else
                       TicketPolicy::OverviewScope.new(current_user).resolve
                     end
        
        # Apply the custom filter condition on top of permission scope
        scoped_tickets = base_scope.where(query, *bind_params)
        scoped_tickets = scoped_tickets.joins(tables) if tables.present?
        
        ticket_list = scoped_tickets.order("#{order_by} #{order_direction}").limit(2000)
        
        ticket_list.each do |ticket|
          ticket_meta = {
            id:         ticket.id,
            title:      ticket.title,
            number:     ticket.number,
            created_at: ticket.created_at,
          }
          
          tickets.push ticket_meta
          assets = ticket.assets(assets)
        end
      end
    rescue => e
      Rails.logger.error "Custom filter query error: #{e.message}"
      # Continue with empty tickets list
    end
    
    result = {
      overview: overview_data,
      tickets: tickets,
      tickets_count: tickets.length,
      count:   tickets.length,
    }
    
    render json: {
      assets: assets,
      index:  result,
    }
  end

end
