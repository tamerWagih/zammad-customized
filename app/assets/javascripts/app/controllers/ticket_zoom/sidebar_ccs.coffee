class SidebarCcs extends App.Controller
  constructor: (params) ->
    super
    @ccs = params.ccs || []

  sidebarItem: =>
    # Only show for agent view
    return unless @ticket.currentView() is 'agent'

    # Only agents and customers can see CCs
    return unless @permissionCheck('ticket.agent') or @permissionCheck('ticket.customer')

    @item = {
      name: 'ccs'
      badgeIcon: 'group'
      badgeCallback: @badgeRender
      sidebarHead: __('CC')
      sidebarCallback: @showPanel
      sidebarActions: []
    }

    # Add action button if user can edit ticket
    if @ticket.editable && @ticket.editable()
      @item.sidebarActions.push(
        title: __('Add CC')
        name: 'cc-add'
        callback: @addCc
      )

    @item

  badgeRender: (el) =>
    @badgeEl = el
    @badgeRenderLocal()

  badgeRenderLocal: =>
    return if !@badgeEl

    ccs = @ccs || []
    count = ccs.length

    @badgeEl.html(App.view('generic/sidebar_tabs_item')(
      name: 'ccs'
      icon: 'group'
      counterPossible: count > 0
      counter: count
    ))

  reload: (args) =>
    # Update local data if provided (same as SidebarApprovals)
    if args.ccs?
      @ccs = args.ccs

    # Update badge count
    @badgeRenderLocal()

    # Reload widget if it exists
    if @widget && @widget.reload
      @widget.reload(@ccs)

  showPanel: (el) =>
    @elSidebar = el

    # Create widget and pass data (same as SidebarApprovals)
    @widget = new App.WidgetCcs(
      el: @elSidebar
      ticket_id: @ticket.id
      ticket: @ticket
      ccs: @ccs  # Pass data from parent
    )

  addCc: =>
    new App.TicketCcAdd(
      ticket_id: @ticket.id
      callback: =>
        # Refresh widget by fetching from API
        @widget.fetch() if @widget && @widget.fetch
    )

App.Config.set('460-Ccs', SidebarCcs, 'TicketZoomSidebar')

