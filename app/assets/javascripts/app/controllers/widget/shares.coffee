class App.WidgetShares extends App.Controller
  events:
    'click .js-edit-share': 'editShare'
    'click .js-delete-share': 'deleteShare'
    'click .js-revoke-share': 'revokeShare'
    'click .js-update-permissions': 'updatePermissions'

  constructor: ->
    super
    console.log('WidgetShares constructor called', @el, @ticket_id)
    @render()

  render: (data) =>
    console.log('WidgetShares render called', @el, data)
    
    # Generate sample shares data for demonstration
    shares = [
      {
        id: 1
        user: 'Alice Williams'
        permissions: ['read', 'comment']
        message: 'Shared for review and feedback'
        created_at: new Date().toISOString()
        expires_at: new Date(Date.now() + 7 * 24 * 3600000).toISOString()
        status: 'active'
      }
      {
        id: 2
        user: 'Bob Rodriguez'
        permissions: ['read']
        message: 'Read-only access for documentation'
        created_at: new Date(Date.now() - 7200000).toISOString()
        expires_at: null
        status: 'active'
      }
    ]

    console.log('About to render shares widget with data:', shares)
    
    # Render the full template with sample data
    @html App.view('widget/shares')(
      shares: shares
      ticket_id: @ticket_id
    )
    
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
    # Simulate real share update by re-rendering
    @render()
    @refresh() if @callback

  shareError: (xhr, status, error) =>
    @notify(
      type: 'error'
      msg:  __('Failed to update share')
    )

  refresh: =>
    if @callback
      @callback()
