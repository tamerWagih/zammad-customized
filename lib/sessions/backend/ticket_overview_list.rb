# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Sessions::Backend::TicketOverviewList < Sessions::Backend::Base

  def self.reset(user_id)
    Rails.cache.write("TicketOverviewPull::#{user_id}", { needed: true })
  end

  def initialize(user, asset_lookup, client = nil, client_id = nil, ttl = 7) # rubocop:disable Lint/MissingSuper
    @user                 = user
    @client               = client
    @client_id            = client_id
    @ttl                  = ttl
    @asset_lookup         = asset_lookup
    @last_index_lists     = nil
    @last_overview        = {}
    @last_overview_change = nil
    @last_ticket_change   = nil
    @last_full_fetch      = nil
  end

  def self.overview_history_append(overview, user_id)
    key = "TicketOverviewHistory::#{user_id}"
    history = Rails.cache.read(key) || []

    history.prepend overview
    history.uniq!
    if history.count > 4
      history.pop
    end

    Rails.cache.write(key, history)
  end

  def self.overview_history_get(user_id)
    Rails.cache.read("TicketOverviewHistory::#{user_id}")
  end

  def load

    # get whole collection
    index_and_lists = nil
    local_overview_changed = overview_changed?
    if !@last_index_lists || !@last_full_fetch || @last_full_fetch < (Time.zone.now.to_i - 60) || local_overview_changed

      # check if min one ticket has changed
      return if !ticket_changed?(true) && !local_overview_changed

      # LAZY LOADING: Get counts for all overviews (fast)
      index_and_lists = Ticket::Overviews.index_counts_only(@user)
      
      # Get tickets ONLY for recently selected overviews (up to 4)
      recent_views = Sessions::Backend::TicketOverviewList.overview_history_get(@user.id)
      if recent_views.present?
        recent_with_tickets = Ticket::Overviews.index(@user, recent_views)
        # Merge tickets into count-only results
        index_and_lists.each do |item|
          match = recent_with_tickets.find { |r| r[:overview][:id] == item[:overview][:id] }
          item[:tickets] = match[:tickets] if match
        end
      end
      
      @last_full_fetch = Time.zone.now.to_i
    else

      # check if min one ticket has changed
      return if !ticket_changed? && !local_overview_changed

      index_and_lists_local = Ticket::Overviews.index(@user, Sessions::Backend::TicketOverviewList.overview_history_get(@user.id))

      # compare index_and_lists_local to index_and_lists_local
      # return if no changes

      index_and_lists = []
      @last_index_lists.each do |last_index|
        found_in_particular_index = false
        index_and_lists_local.each do |local_index|
          next if local_index[:overview][:id] != last_index[:overview][:id]

          index_and_lists.push local_index
          found_in_particular_index = true
          break
        end
        next if found_in_particular_index == true

        index_and_lists.push last_index
      end
    end

    # no data exists
    return if index_and_lists.blank?

    # no change exists
    return if @last_index_lists == index_and_lists

    # remember last state
    @last_index_lists = index_and_lists

    index_and_lists
  end

  def local_to_run?
    return false if !@time_now

    return true if pull_overview?

    false
  end

  def pull_overview?
    result = Rails.cache.read("TicketOverviewPull::#{@user.id}")
    Rails.cache.delete("TicketOverviewPull::#{@user.id}") if result
    return true if result

    false
  end

  def push
    return if !to_run? && !local_to_run?

    @time_now = Time.zone.now.to_i

    # load current data
    index_and_lists = load
    return if !index_and_lists

    # push overview index
    indexes = []
    index_and_lists.each do |index|
      overview = Overview.lookup(id: index[:overview][:id])
      next if !overview

      meta = {
        id:    overview.id,
        name:  overview.name,
        prio:  overview.prio,
        link:  overview.link,
        count: index[:count],
      }
      indexes.push meta
    end
    
    # Add custom filters - cache the data for reuse in the second loop
    # OPTIMIZATION: Get full data once instead of calling count_tickets_for_filter then get_custom_filter_data
    custom_filters = @user.preferences[:custom_filters] || []
    @cached_custom_filter_data ||= {}
    
    custom_filters.each do |filter|
      next unless filter['active']
      
      # Get full filter data (includes count) and cache it
      filter_data = get_custom_filter_data(filter)
      next if !filter_data
      
      filter_link = filter['link'] || filter['id']
      @cached_custom_filter_data[filter_link] = filter_data
      
      meta = {
        id:        filter['id'],
        name:      filter['name'],
        prio:      filter['prio'] || 2000,
        link:      filter['link'],
        count:     filter_data[:count],  # Use count from cached data
        is_custom: true,
      }
      indexes.push meta
    end
    

    if @client
      @client.log "push overview_index for user #{@user.id}"
      @client.send(
        event: 'ticket_overview_index',
        data:  indexes,
      )
    end

    @time_now = Time.zone.now.to_i

    # push overviews
    results = []
    assets  = AssetsSet.new
    index_and_lists.each do |data|

      # do not deliver unchanged lists
      next if @last_overview[data[:overview][:id]] == [data[:tickets], data[:overview]]

      @last_overview[data[:overview][:id]] = [data[:tickets], data[:overview]]

      overview = Overview.lookup(id: data[:overview][:id])
      next if !overview

      if asset_needed?(overview)
        assets = asset_push(overview, assets)
      end
      data[:tickets].each do |ticket_meta|
        next if !asset_needed_by_updated_at?('Ticket', ticket_meta[:id], ticket_meta[:updated_at])

        ticket = Ticket.lookup(id: ticket_meta[:id])
        next if !ticket

        assets = asset_push(ticket, assets)
      end

      data[:assets] = assets.to_h

      if @client
        @client.log "push overview_list #{overview.link} for user #{@user.id}"

        # send update to browser
        @client.send(
          event: 'ticket_overview_list',
          data:  data,
        )
      else
        result = {
          event: 'ticket_overview_list',
          data:  data,
        }
        results.push result
      end

      assets.flush
    end
    
    # Push custom filter overviews (like standard overviews)
    # OPTIMIZATION: Use cached data from first loop instead of querying again
    custom_filters = @user.preferences[:custom_filters] || []
    custom_filters.each do |filter|
      next unless filter['active']
      
      # Use cached data from first loop (no duplicate query)
      filter_link = filter['link'] || filter['id']
      filter_data = @cached_custom_filter_data[filter_link]
      next if !filter_data
      

      # Check if this custom filter has changed (similar to standard overviews)
      filter_link = filter['link'] || filter['id']
      last_filter_state = @last_overview[filter_link]
      
      # Build current state: ticket IDs, updated_at timestamps, and count for comparison
      # Sort by ID for consistent comparison
      current_ticket_state = filter_data[:tickets].map { |t| { id: t[:id].to_i, updated_at: t[:updated_at] } }.sort_by { |t| t[:id] }
      current_ticket_ids = current_ticket_state.map { |t| t[:id] }.sort
      current_count = filter_data[:count]
      current_filter_state = [current_ticket_state, filter_data[:overview], current_count]
      
      # Check if filter state changed
      filter_changed = last_filter_state != current_filter_state
      
      # Always refresh if:
      # 1. Filter hasn't been sent before (first time) - !last_filter_state
      # 2. Filter state changed (different tickets, different count, or different updated_at) - filter_changed
      # NOTE: We don't check ticket_changed? here because if tickets changed, we're already in push()
      # The state comparison should catch ticket updated_at changes, but we're more aggressive for custom filters
      needs_refresh = !last_filter_state || filter_changed
      
      # Skip only if filter unchanged (saves bandwidth)
      next if !needs_refresh && last_filter_state
      
      # Update last state
      @last_overview[filter_link] = current_filter_state
      
      # Prepare assets for custom filter
      filter_assets = AssetsSet.new
      filter_data[:tickets].each do |ticket_meta|
        next if !asset_needed_by_updated_at?('Ticket', ticket_meta[:id], ticket_meta[:updated_at])
        
        ticket = Ticket.lookup(id: ticket_meta[:id])
        next if !ticket
        
        filter_assets = asset_push(ticket, filter_assets)
      end
      
      filter_data[:assets] = filter_assets.to_h
      
      if @client
        @client.log "push custom filter overview_list #{filter_link} for user #{@user.id}"
        
        # send update to browser (same event as standard overviews)
        @client.send(
          event: 'ticket_overview_list',
          data:  filter_data,
        )
      else
        result = {
          event: 'ticket_overview_list',
          data:  filter_data,
        }
        results.push result
      end
      
      filter_assets.flush
    end
    
    return results if !@client

    nil
  end

  def overview_changed?

    # check if min one overview has changed
    last_overview_change = Overview.latest_change
    return false if last_overview_change == @last_overview_change

    @last_overview_change = last_overview_change

    true
  end

  def ticket_changed?(reset = false)

    # check if min one ticket has changed
    last_ticket_change = Ticket.latest_change
    return false if last_ticket_change == @last_ticket_change

    @last_ticket_change = last_ticket_change if reset

    true
  end

  def count_tickets_for_filter(filter)
    condition = filter['condition'] || {}
    
    # Use Ticket selector to count tickets with custom filter context
    query, bind_params, tables = Ticket.selector2sql(
      condition, 
      current_user: @user,
      custom_filter_context: true  # Enable custom filter attributes
    )
    
    return 0 if query.blank?
    
    # CRITICAL: Apply user permission scope first (like Zammad's overview system)
    base_scope = if condition.key?('ticket.mention_user_ids')
                   TicketPolicy::ReadScope.new(@user).resolve
                 else
                   TicketPolicy::OverviewScope.new(@user).resolve
                 end
    
    # Apply the custom filter condition on top of permission scope
    scoped_tickets = base_scope.where(query, *bind_params)
    scoped_tickets = scoped_tickets.joins(tables) if tables.present?
    
    scoped_tickets.count
  rescue => e
    Rails.logger.error "Error counting tickets for custom filter: #{e.message}"
    0
  end

  def get_custom_filter_data(filter)
    # Similar to Ticket::Overviews.index but for custom filters
    # Returns data in the same format as standard overviews
    
    condition = filter['condition'] || {}
    order = filter['order'] || { 'by' => 'created_at', 'direction' => 'DESC' }
    view = filter['view'] || { 's' => ['number', 'title', 'customer', 'state', 'created_at'] }
    
    # Clean up empty values in condition
    condition.each do |key, value_hash|
      if value_hash.is_a?(Hash) && value_hash[:value].is_a?(Array) && value_hash[:value].empty?
        condition.delete(key)
      end
    end
    
    # Get pagination (same as default overviews)
    limit = Ticket::Overviews.limit_per_overview
    
    # Build overview data
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
    total_count = 0
    
    begin
      # Get tickets based on condition with custom filter context
      query, bind_params, tables = Ticket.selector2sql(
        condition, 
        current_user: @user,
        custom_filter_context: true
      )
      
      if query.present?
        # Apply ordering
        order_by = order['by'] || 'created_at'
        order_direction = order['direction'] || 'DESC'
        
        # CRITICAL: Apply user permission scope first (like Zammad's overview system)
        base_scope = if condition.key?('ticket.mention_user_ids')
                       TicketPolicy::ReadScope.new(@user).resolve
                     else
                       TicketPolicy::OverviewScope.new(@user).resolve
                     end
        
        # Apply the custom filter condition on top of permission scope
        scoped_tickets = base_scope.where(query, *bind_params)
        scoped_tickets = scoped_tickets.joins(tables) if tables.present?
        
        # Get total count for pagination
        total_count = scoped_tickets.distinct.count
        
        # Apply pagination (limit)
        ticket_list = scoped_tickets.order("#{order_by} #{order_direction}")
                                     .limit(limit)
        
        ticket_list.each do |ticket|
          ticket_meta = {
            id:         ticket.id,
            title:      ticket.title,
            number:     ticket.number,
            created_at: ticket.created_at,
            updated_at: ticket.updated_at,
          }
          
          tickets.push ticket_meta
        end
      end
    rescue => e
      Rails.logger.error "Error loading custom filter data: #{e.message}"
      # Continue with empty tickets list
    end
    
    {
      overview: overview_data,
      tickets: tickets,
      tickets_count: tickets.length,
      count: total_count,
    }
  end

end
