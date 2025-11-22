class App.TicketZoomOverviewNavigator extends App.Controller
  @include App.TicketNavigable

  events:
    'click a': 'open'

  constructor: ->
    super

    return if !@overview_id

    # rebuild overview navigator if overview has changed
    lateUpdate = =>
      @delay(@render, 2600, 'overview-navigator')

    # Check if this is a custom filter (UUID format) or standard overview (numeric ID)
    @overview = App.Overview.find(@overview_id)
    
    # Determine the link to use for OverviewListCollection
    # For standard overviews, use overview.link
    # For custom filters, @overview_id is the link (UUID)
    if @overview
      @overview_link = @overview.link
    else
      # If overview not found, assume it's a custom filter link (UUID)
      # Custom filters use their link as the ID
      @overview_link = @overview_id
    
    @bindId = App.OverviewListCollection.bind(@overview_link, lateUpdate, true)

    # Ensure overview data is fetched (especially important for custom filters)
    if !App.OverviewListCollection.get(@overview_link)
      App.OverviewListCollection.fetch(@overview_link)

    @render()

  release: =>
    App.OverviewListCollection.unbind(@bindId)

  render: =>
    if !@overview_id || !@overview_link
      @html('')
      return

    # get overview data from OverviewListCollection using the link
    overview = App.OverviewListCollection.get(@overview_link)
    return if !overview
    return if !overview.tickets || overview.tickets.length is 0
    return if !overview.overview
    
    # Ensure ticket_id is a number for comparison
    ticket_id = parseInt(@ticket_id, 10)
    
    current_position = 0
    found            = false
    item_next        = false
    item_previous    = false
    for ticket in overview.tickets
      current_position += 1
      # Compare ticket IDs (handle both string and number)
      ticket_id_to_compare = if typeof ticket.id is 'string' then parseInt(ticket.id, 10) else ticket.id
      if ticket_id_to_compare is ticket_id
        found = true
        item_next         = overview.tickets[current_position]
        item_previous     = overview.tickets[current_position-2]
        break

    if !found
      @html('')
      return

    # get next/previous ticket
    if item_next
      next = App.Ticket.find(item_next.id)
    if item_previous
      previous = App.Ticket.find(item_previous.id)

    @html App.view('ticket_zoom/overview_navigator')(
      title:            overview.overview.name
      total_count:      overview.count
      current_position: current_position
      next:             next
      previous:         previous
    )

  open: (e) =>
    e.preventDefault()
    ticketLink = $(e.target)

    if (id = ticketLink.data('id'))?
      url = ticketLink.attr('href')
    else if (id = ticketLink.closest('a').data('id'))?
      url = ticketLink.closest('a').attr('href')
    else
      return

    @taskOpenTicket(id, url)
