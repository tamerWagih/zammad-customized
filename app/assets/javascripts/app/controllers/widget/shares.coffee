class App.WidgetShares extends App.Controller
  events:
    'click .js-revoke-share': 'revokeShare'
    'click .js-delete-share': 'deleteShare'
    'click .js-edit-share': 'editShare'
    'click .js-share-ticket': 'openShareTicket'

  constructor: ->
    super
    
    # Standard pattern: if shares passed from parent, use them (like WidgetTag)
    if @shares
      @localShares = _.clone(@shares)
      @render()
      return
    
    # Fallback: fetch from API if not provided
    @fetch()

  fetch: =>
    return unless @ticket_id
    
    @ajax(
      id:          'load_shares'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/shares"
      processData: true
      success:     (data) =>
        @localShares = data?.shares || []
        @render()
      error: (xhr, status, error) =>
        console.error 'Failed to load shares:', status, error
        @localShares = []
        @render()
    )

  reload: (shares) =>
    # PRIMARY PROTECTION: Skip if data is unchanged (prevents unnecessary re-renders)
    # This is the main guard - if data hasn't changed, never re-render
    if @localShares && _.isEqual(@localShares, shares)
      console.log "[SHARES] Skipping reload - data unchanged"
      return
    
    # SECONDARY PROTECTION: Skip very rapid successive updates (< 500ms)
    # This only blocks if:
    # 1. We just did a local update AND
    # 2. New data is DIFFERENT but arrived too quickly (prevents flicker from race conditions)
    # This allows WebSocket updates after ~1s to go through even after local action
    if @lastLocalUpdateTime
      timeSinceUpdate = Date.now() - @lastLocalUpdateTime
      if timeSinceUpdate < 500
        console.log "[SHARES] Skipping reload - too soon after local update (#{timeSinceUpdate}ms)"
        return
    
    # Data is different AND enough time passed → update UI
    @localShares = _.clone(shares)
    @render()

  render: =>
    # Prevent unnecessary re-renders (like WidgetTag)
    return if @lastLocalShares && _.isEqual(@lastLocalShares, @localShares)
    @lastLocalShares = _.clone(@localShares)
    
    current_user = App.User.current()
    shares_data = @localShares || []
    
    # Refresh ticket for permission checks
    if @ticket_id
      @ticket = App.Ticket.findNative(@ticket_id) || App.Ticket.fullLocal(@ticket_id)
    
    # Check if current user can manage shares
    can_manage = @ticket && @ticket.editable && @ticket.editable()
    
    # Prepare display data
    for share in shares_data
      share.can_manage = can_manage
      share.is_active = share.status is 'active'
      share.is_revoked = share.status is 'revoked'
      
      # Format dates (use App.i18n for timestamp formatting)
      if share.created_at
        share.created_at_formatted = App.i18n.translateTimestamp(share.created_at)
      if share.updated_at
        share.updated_at_formatted = App.i18n.translateTimestamp(share.updated_at)
      
      # Get group name
      if share.group_id
        group = App.Group.find(share.group_id)
        share.group_name = group?.name || share.group_name
      
      # Get shared_by name properly (handle both object and string formats)
      if share.shared_by
        if typeof share.shared_by is 'object'
          share.shared_by_name = share.shared_by_name || share.shared_by.firstname + ' ' + share.shared_by.lastname
        else
          share.shared_by_name = share.shared_by
    
    @html App.view('widget/shares')(
      shares: shares_data
      ticket_id: @ticket_id
      current_user_id: current_user.id
    )

  revokeShare: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('id')
    return unless share_id
    
    new App.ControllerConfirm(
      message: __('Are you sure you want to revoke this share?')
      callback: =>
        @ajax(
          id:   'revoke_share'
          type: 'POST'
          url:  "#{@apiPath}/tickets/#{@ticket_id}/shares/#{share_id}/revoke"
          success: (data) =>
            # Mark that we just did a local update
            @lastLocalUpdateTime = Date.now()
            
            # Update local data immediately - set status to 'revoked'
            share = _.find(@localShares, (s) -> parseInt(s.id) is parseInt(share_id))
            if share
              share.status = 'revoked'
              # Or use the response data if available
              if data?.share
                index = _.findIndex(@localShares, (s) -> parseInt(s.id) is parseInt(share_id))
                @localShares[index] = data.share if index >= 0
            
            # Re-render locally without API fetch
            @render()
            
            # Clear permission cache - will be updated by WebSocket event
            ticket = App.Ticket.findNative(@ticket_id)
            if ticket
              ticket._shares_cache = @localShares
            
            # Trigger sidebar update for badge
            App.Event.trigger('ui::ticket::sidebarRerender', ticket_id: @ticket_id)
            
            # WebSocket will handle eventual consistency
          error: (xhr, status, error) =>
            console.error 'Failed to revoke share:', status, error
            @notify(
              type: 'error'
              msg: App.i18n.translateContent('Failed to revoke share.')
            )
        )
      container: @el.closest('.content')
    )

  deleteShare: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('id')
    return unless share_id
    
    new App.ControllerConfirm(
      message: __('Are you sure you want to delete this share?')
      callback: =>
        @ajax(
          id:   'delete_share'
          type: 'DELETE'
          url:  "#{@apiPath}/tickets/#{@ticket_id}/shares/#{share_id}"
          success: =>
            # Mark that we just did a local update
            @lastLocalUpdateTime = Date.now()
            
            # Remove from local data immediately
            @localShares = _.filter(@localShares, (s) -> parseInt(s.id) isnt parseInt(share_id))
            
            # Re-render locally without API fetch
            @render()
            
            # Clear permission cache - will be updated by WebSocket event
            ticket = App.Ticket.findNative(@ticket_id)
            if ticket
              ticket._shares_cache = @localShares
            
            # Trigger sidebar update for badge
            App.Event.trigger('ui::ticket::sidebarRerender', ticket_id: @ticket_id)
            
            # WebSocket will handle eventual consistency
          error: (xhr, status, error) =>
            # Only show error if not 404 (item might be already deleted)
            if xhr.status isnt 404
              console.error 'Failed to delete share:', status, error
              @notify(
                type: 'error'
                msg: App.i18n.translateContent('Failed to delete share.')
              )
        )
      container: @el.closest('.content')
    )

  editShare: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('id')
    return unless share_id
    
    # Find the share in local data
    share = _.find(@localShares, (s) -> parseInt(s.id) is parseInt(share_id))
    return unless share
    
    new App.TicketShareEdit(
      ticket_id: @ticket_id
      share: share
      container: @el.closest('.content')
      callback: (updated_share) =>
        # Update local data immediately with response data
        if updated_share
          # Mark that we just did a local update
          @lastLocalUpdateTime = Date.now()
          
          index = _.findIndex(@localShares, (s) -> parseInt(s.id) is parseInt(updated_share.id))
          if index >= 0
            @localShares[index] = updated_share
            # Re-render locally without API fetch
            @render()
            
            # Update permission cache
            ticket = App.Ticket.findNative(@ticket_id)
            if ticket
              ticket._shares_cache = @localShares
            
            # Trigger sidebar update for badge
            App.Event.trigger('ui::ticket::sidebarRerender', ticket_id: @ticket_id)
        # WebSocket will handle eventual consistency
    )

  openShareTicket: (e) =>
    e.preventDefault()
    new App.TicketShareCreate(
      ticket_id: @ticket_id
      callback: =>
        # Reload fresh data from API after creating
        @fetch()
    )


