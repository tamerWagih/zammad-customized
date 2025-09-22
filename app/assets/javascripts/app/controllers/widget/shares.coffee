class App.WidgetShares extends App.Controller
  events:
    'click .js-edit-share': 'editShare'
    'click .js-delete-share': 'deleteShare'
    'click .js-revoke-share': 'revokeShare'
    'click .js-update-permissions': 'updatePermissions'

  constructor: ->
    super
    @render()

  render: =>
    # Render shares list with interactive elements
    @html $(App.view('widget/shares')({
      shares: @shares
      ticket_id: @ticket_id
    }))

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
    @refresh() if @callback

  shareError: (xhr, status, error) =>
    @notify(
      type: 'error'
      msg:  __('Failed to update share')
    )

  refresh: =>
    if @callback
      @callback()
