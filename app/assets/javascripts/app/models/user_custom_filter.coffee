class App.UserCustomFilter extends App.Model
  @configure 'UserCustomFilter', 'name', 'link', 'condition', 'order', 'view', 'group_by', 'prio', 'active', 'is_custom', 'user_id', 'created_at', 'updated_at'
  @extend Spine.Model.Ajax
  @url: @apiPath + '/user_custom_filters'
  @configure_attributes = [
    { name: 'name',       display: __('Name'),                tag: 'input',    type: 'text', limit: 100, 'null': false },
    { name: 'link',       display: __('Link'),                readonly: 1 },
    { name: 'condition',  display: __('Conditions for shown tickets'), tag: 'ticket_selector', null: false },
    {
      name:    'view::s'
      display: __('Attributes')
      tag:     'checkboxTicketAttributes'
      default: ['number', 'title', 'state', 'created_at']
      null:    false
      translate: true
    },
    {
      name:    'order::by',
      display: __('Sorting by'),
      tag:     'selectTicketAttributes'
      default: 'created_at'
      null:    false
      translate: true
    },
    {
      name:    'order::direction'
      display: __('Sorting order')
      tag:     'select'
      default: 'DESC'
      null:    false
      translate: true
      options:
        ASC:   __('ascending')
        DESC:  __('descending')
    },
    {
      name:    'group_by'
      display: __('Grouping by')
      tag:     'select'
      default: ''
      null:    true
      nulloption: true
      translate:  true
      options:
        customer:   'Customer'
        state:      'State'
        priority:   'Priority'
        group:      'Group'
        owner:      'Owner'
    },
    { name: 'active',         display: __('Active'),      tag: 'active', default: true },
    { name: 'prio',           display: __('Position'),    tag: 'integer', type: 'number', limit: 100, null: true },
    { name: 'created_at',     display: __('Created'),     tag: 'datetime', readonly: 1 },
    { name: 'updated_at',     display: __('Updated'),     tag: 'datetime', readonly: 1 },
  ]
  @configure_delete = true
  @configure_clone = false

  uiUrl: ->
    "#ticket/view/#{@link}"

  tickets: =>
    App.OverviewListCollection.get(@link).tickets

  indexOf: (ticket) =>
    # coerce id to Ticket object
    ticket = App.Ticket.find(ticket) if !(isNaN ticket)
    _.findIndex(@tickets(), (t) -> t.id == ticket.id)

  nextTicket: (thisTicket) =>
    thisIndex = @indexOf(thisTicket)
    if thisIndex >= 0 then @tickets()[thisIndex + 1] else undefined

  prevTicket: (thisTicket) =>
    @tickets()[@indexOf(thisTicket) - 1]

