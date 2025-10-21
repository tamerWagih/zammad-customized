class App.TicketCustomFilterCreate extends App.ControllerModal
  head: __('Create Custom Filter')
  buttonSubmit: __('Create')
  buttonCancel: __('Cancel')

  content: =>
    configure_attributes = [
      { name: 'name',       display: __('Name'),                tag: 'input',    type: 'text', limit: 100, 'null': false },
      { name: 'condition',  display: __('Conditions for shown tickets'), tag: 'ticket_selector', null: false, default: { operator: 'AND', children: [] } },
      {
        name:    'view::s'
        display: __('Attributes')
        tag:     'checkboxTicketAttributes'
        default: ['number', 'title', 'customer', 'state', 'created_at']
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
          '':         '-'
          customer:   __('Customer')
          state:      __('State')
          priority:   __('Priority')
          group:      __('Group')
          owner:      __('Owner')
      },
      { name: 'active',         display: __('Active'),      tag: 'active', default: true },
    ]
    
    @controller = new App.ControllerForm(
      model:
        configure_attributes: configure_attributes
      autofocus: true
    )
    @controller.form

  onSubmit: (e) =>
    e.preventDefault()
    @formDisable(e)
    
    # Get form params
    params = @formParam(e.target)
    
    # Create the filter
    @ajax(
      id:   'user_custom_filters_create'
      type: 'POST'
      url:  "#{@apiPath}/user_custom_filters"
      data: JSON.stringify(params)
      processData: true
      success: (data, status, xhr) =>
        # Refresh the overview list
        App.OverviewIndexCollection.fetch()
        
        # Close modal
        @close()
        
        # Show success message
        @notify(
          type: 'success'
          msg:  __('Custom filter has been created successfully.')
        )
        
        # Navigate to the new filter
        @navigate "#ticket/view/#{data.link}"
      error: (xhr, status, error) =>
        @formEnable(e)
        @notify(
          type: 'error'
          msg:  __('Unable to create custom filter.')
        )
    )

