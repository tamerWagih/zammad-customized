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
    # ONLY PROTECTION: Skip if data is unchanged (Zammad WidgetTag pattern)
    # This is sufficient - if data hasn't changed, no need to re-render
    # If data HAS changed, always update (even if rapid)
    if @localShares && _.isEqual(@localShares, shares)
      console.log "[SHARES] Skipping reload - data unchanged"
      return
    
    # Data is different → update UI immediately
    console.log "[SHARES] Reload triggered - data changed"
    @localShares = _.clone(shares)
    @stopLoading()  # Clear any loading state when fresh data arrives
    @render()

  render: =>
    # Prevent unnecessary re-renders (like WidgetTag)
    return if @lastLocalShares && _.isEqual(@lastLocalShares, @localShares)
    @lastLocalShares = _.clone(@localShares)
    
    current_user = App.User.current()
    # Clone data before modification to prevent mutation of @localShares
    # This ensures _.isEqual() works correctly on next reload
    shares_data = _.map(@localShares || [], (s) -> _.clone(s))
    
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
      current_user_id: current_user.id.toString()  # Convert to string to match backend format
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
            # Update local data immediately - set status to 'revoked'
            share = _.find(@localShares, (s) -> parseInt(s.id) is parseInt(share_id))
            if share
              share.status = 'revoked'
              # Or use response data if available
              if data?.share
                index = _.findIndex(@localShares, (s) -> parseInt(s.id) is parseInt(share_id))
                @localShares[index] = data.share if index >= 0
            
            # Re-render locally without API fetch
            @render()
            
            # Update permission cache
            ticket = App.Ticket.findNative(@ticket_id)
            if ticket
              ticket._shares_cache = @localShares
            
            # WebSocket will handle receiver updates
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
            # Remove from local data immediately
            @localShares = _.filter(@localShares, (s) -> parseInt(s.id) isnt parseInt(share_id))
            
            # Re-render locally without API fetch
            @render()
            
            # Clear permission cache - will be updated by WebSocket event
            ticket = App.Ticket.findNative(@ticket_id)
            if ticket
              ticket._shares_cache = @localShares
            
            # Don't trigger sidebar rerender - WebSocket will handle it with fresh data
            
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
        # Optimistic update: immediately update local data
        index = _.findIndex(@localShares, (s) -> parseInt(s.id) is parseInt(updated_share.id))
        if index >= 0
          @localShares[index] = updated_share
          @render()  # Re-render with updated data
        
        # No loading spinner needed - optimistic update shows change immediately
        # WebSocket will provide final confirmation when it arrives
    )

  openShareTicket: (e) =>
    e.preventDefault()
    new App.TicketShareCreate(
      ticket_id: @ticket_id
      callback: =>
        # Reload fresh data from API after creating
        @fetch()
    )


