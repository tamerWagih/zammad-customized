class App.TicketZoomSidebar extends App.ControllerObserver
  model: 'Ticket'
  observe:
    customer_id: true
    organization_id: true

  release: =>
    super
    if @sidebarBackends
      for key, value of @sidebarBackends
        @sidebarBackends[key]?.releaseController()

  get: (key) ->
    return @sidebarBackends[key]

  reload: (args) =>
    # Keep internal state in sync so subsequent render() uses fresh data.
    # This is critical for real-time updates (approvals/shares/ccs) where we call reload()
    # without rebuilding the entire sidebar.
    if args?
      @params           = args.params           if args.params?
      @query            = args.query            if args.query?
      @formMeta         = args.formMeta         if args.formMeta?
      @markForm         = args.markForm         if args.markForm?
      @tags             = args.tags             if args.tags?
      @mentions         = args.mentions         if args.mentions?
      @time_accountings = args.time_accountings if args.time_accountings?
      @links            = args.links            if args.links?
      @approvals        = args.approvals        if args.approvals?
      @shares           = args.shares           if args.shares?
      @ccs              = args.ccs              if args.ccs?
      @parent           = args.parent           if args.parent?

    for key, backend of @sidebarBackends
      if backend && backend.reload
        backend.reload(args)

  commit: (args) =>
    for key, backend of @sidebarBackends
      if backend && backend.commit
        backend.commit(args)

  postParams: (args) =>
    for key, backend of @sidebarBackends
      if backend && backend.postParams
        backend.postParams(args)

  render: (ticket) =>
    ticketModel = ticket
    if !ticketModel?.currentView?()
      if @object_id && App.Ticket.exists(@object_id)
        ticketModel = App.Ticket.fullLocal(@object_id)

    return unless ticketModel?.currentView?()
    ticket = ticketModel
    @sidebarBackends ||= {}
    @sidebarItems = []
    sidebarBackends = App.Config.get('TicketZoomSidebar')
    keys = _.keys(sidebarBackends).sort()
    for key in keys
      if !@sidebarBackends[key] || !@sidebarBackends[key].reload
        @sidebarBackends[key] = new sidebarBackends[key](
          ticket:           ticket
          query:            @query
          taskGet:          @taskGet
          taskKey:          @taskKey
          formMeta:         @formMeta
          markForm:         @markForm
          tags:             @tags
          mentions:         @mentions
          time_accountings: @time_accountings
          links:            @links
          approvals:        @approvals
          shares:           @shares
          ccs:              @ccs
          parent:           @parent
        )
      else
        @sidebarBackends[key].reload(
          params:           @params
          query:            @query
          formMeta:         @formMeta
          markForm:         @markForm
          tags:             @tags
          mentions:         @mentions
          time_accountings: @time_accountings
          links:            @links
          approvals:        @approvals
          shares:           @shares
          ccs:              @ccs
          parent:           @parent
        )
      @sidebarItems.push @sidebarBackends[key]

    if @sidebar
      @sidebar.releaseController()

    tabsSidebarEl = @$('.tabsSidebar')
    
    # Clear existing sidebar content to prevent duplication
    tabsSidebarEl.empty()
    
    try
      @sidebar = new App.Sidebar(
        el:           tabsSidebarEl
        sidebarState: @sidebarState
        items:        @sidebarItems
      )
    catch error
      console.error('Error creating App.Sidebar:', error)
