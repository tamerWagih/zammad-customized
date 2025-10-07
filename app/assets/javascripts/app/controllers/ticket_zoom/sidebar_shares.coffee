class SidebarShares extends App.Controller
  constructor: ->
    super

  sidebarItem: =>
    # Only show for agent view
    return unless @ticket.currentView() is 'agent'
    
    # Only agents and admins can see shares
    return unless @permissionCheck('ticket.agent') or @permissionCheck('admin.*')

    @item = {
      name: 'shares'
      badgeIcon: 'team'
      badgeCallback: @badgeRender
      sidebarHead: __('Shares')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Add action button if user can edit ticket
    if @ticket.editable && @ticket.editable()
      @item.sidebarActions.push(
        title: __('Share Ticket')
        name: 'share-ticket'
        callback: @shareTicket
      )

    @item

  badgeRender: (el) =>
    @badgeEl = el
    @badgeRenderLocal()

  badgeRenderLocal: =>
    return if !@badgeEl
    
    # Count active shares for badge
    shares = @shares || []
    active_count = shares.filter((s) -> s.status is 'active').length
    
    @badgeEl.html(App.view('generic/sidebar_tabs_item')(
      name: 'shares'
      icon: 'group'
      counterPossible: active_count > 0
      counter: active_count
    ))

  reload: (args) =>
    # Standard pattern: update local data if provided (like SidebarTicket)
    if args.shares?
      @shares = args.shares
    
    # Reload widget if it exists
    if @widget && @widget.reload
      @widget.reload(@shares)

  showPanel: (el) =>
    @elSidebar = el
    
    # Standard pattern: create widget and pass data (like SidebarTicket does with WidgetTag)
    @widget = new App.WidgetShares(
      el: @elSidebar
      ticket_id: @ticket.id
      ticket: @ticket
      shares: @shares  # Pass data from parent
    )

  shareTicket: =>
    new ShareTicket(
      ticket_id: @ticket.id
      container: @el.closest('.content')
    )

class ShareTicket extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: __('Share')
  head: __('Share Ticket')

  content: =>
    @ticket = App.Ticket.find(@ticket_id)
    
    content = $( App.view('widget/share_ticket')(
      ticket: @ticket
    ))
    
    content

  onSubmit: (e) =>
    e.preventDefault()
    params = @formParam(e.target)
    
    unless params.group_id
      @formValidate(form: e.target, errors: { group_id: 'required' })
      return
    
    @ajax(
      id:   'create_share'
      type: 'POST'
      url:  "#{@apiPath}/tickets/#{@ticket_id}/shares"
      data: JSON.stringify(params)
      processData: false
      success: =>
        @close()
      error: (xhr, status, error) =>
        console.error 'Failed to create share:', status, error
        @notify(
          type: 'error'
          msg: App.i18n.translateContent('Failed to share ticket.')
        )
    )

App.Config.set('451-Shares', SidebarShares, 'TicketZoomSidebar')
