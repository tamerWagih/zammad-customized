class App.WidgetShares extends App.Controller
  events:
    'click .js-edit-share': 'editShare'
    'click .js-delete-share': 'deleteShare'
    'click .js-revoke-share': 'revokeShare'
    'click .js-update-permissions': 'updatePermissions'

  constructor: ->
    super
    console.log('WidgetShares constructor called', @el, @ticket_id)
    @loadShares()

  loadShares: =>
    console.log('Loading shares for ticket:', @ticket_id)
    
    @ajax(
      id:          'load_shares'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/shares"
      processData: true
      success:     @renderShares
      error:       @renderError
    )

  renderShares: (data, status, xhr) =>
    console.log('Shares loaded:', data)
    shares = data?.shares || []
    @render(shares)

  renderError: (xhr, status, error) =>
    console.error('Error loading shares:', error)
    @html '<div class="sidebar-block"><div class="alert alert-danger">Unable to load shares</div></div>'

  render: (shares) =>
    console.log('WidgetShares render called with data:', shares)
    
    console.log('About to render shares widget with data:', shares)
    
    # Test if template is working
    try
      # Render the full template with real data
      @html App.view('widget/shares')(
        shares: shares
        ticket_id: @ticket_id
      )
    catch error
      console.error('Template rendering error:', error)
      # Fallback to simple HTML if template fails
      @html '<div class="sidebar-block"><h3>Template Error</h3><p>Template failed to render: ' + error.message + '</p></div>'
    
    console.log('Shares widget rendered, element content:', @el.html())

  editShare: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('share-id')
    
    # Open edit modal
    new App.TicketShareEdit(
      share_id: share_id
      ticket_id: @ticket_id
      container: @el.closest('.content')
      callback:  @refresh
    )

  deleteShare: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('share-id')
    
    # Confirm deletion
    @confirm(
      message: __('Are you sure you want to delete this share?')
      callback: =>
        @ajax(
          id:          'delete_share'
          type:        'DELETE'
          url:         "#{@apiPath}/tickets/#{@ticket_id}/shares/#{share_id}"
          processData: true
          success:     @shareSuccess
          error:       @shareError
        )
    )

  revokeShare: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('share-id')
    
    # Confirm revocation
    @confirm(
      message: __('Are you sure you want to revoke this share?')
      callback: =>
        @ajax(
          id:          'revoke_share'
          type:        'POST'
          url:         "#{@apiPath}/tickets/#{@ticket_id}/shares/#{share_id}/revoke"
          processData: true
          success:     @shareSuccess
          error:       @shareError
        )
    )

  updatePermissions: (e) =>
    e.preventDefault()
    share_id = $(e.currentTarget).data('share-id')
    
    # Open permissions modal
    new App.TicketSharePermissions(
      share_id: share_id
      ticket_id: @ticket_id
      container: @el.closest('.content')
      callback:  @refresh
    )

  shareSuccess: (data, status, xhr) =>
    @notify(
      type: 'success'
      msg:  __('Share updated successfully')
    )
    # Reload shares from backend
    @loadShares()
    @callback() if @callback

  shareError: (xhr, status, error) =>
    @notify(
      type: 'error'
      msg:  __('Failed to update share')
    )

  refresh: =>
    if @callback
      @callback()
