class App.WidgetApprovals extends App.Controller
  events:
    'click .js-approve': 'approve'
    'click .js-reject': 'reject'
    'click .js-edit-approval': 'editApproval'
    'click .js-delete-approval': 'deleteApproval'

  constructor: ->
    super
    console.log('WidgetApprovals constructor called', @el, @ticket_id)
    @loadApprovals()

  loadApprovals: =>
    console.log('Loading approvals for ticket:', @ticket_id)
    
    @ajax(
      id:          'load_approvals'
      type:        'GET'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals"
      processData: true
      success:     @renderApprovals
      error:       @renderError
    )

  renderApprovals: (data, status, xhr) =>
    console.log('Approvals loaded:', data)
    approvals = data?.approvals || []
    @render(approvals)

  renderError: (xhr, status, error) =>
    console.error('Error loading approvals:', error)
    @html '<div class="sidebar-block"><div class="alert alert-danger">Unable to load approvals</div></div>'

  render: (approvals) =>
    console.log('WidgetApprovals render called with data:', approvals)
    
    console.log('About to render approvals widget with data:', approvals)
    
    # Test if template is working
    try
      # Render the full template with real data
      @html App.view('widget/approvals')(
        approvals: approvals
        ticket_id: @ticket_id
      )
    catch error
      console.error('Template rendering error:', error)
      # Fallback to simple HTML if template fails
      @html '<div class="sidebar-block"><h3>Template Error</h3><p>Template failed to render: ' + error.message + '</p></div>'
    
    console.log('Approvals widget rendered, element content:', @el.html())

  approve: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    @ajax(
      id:          'approve_approval'
      type:        'POST'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}/approve"
      processData: true
      success:     @approvalSuccess
      error:       @approvalError
    )

  reject: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    @ajax(
      id:          'reject_approval'
      type:        'POST'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}/reject"
      processData: true
      success:     @approvalSuccess
      error:       @approvalError
    )

  editApproval: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    # TODO: Implement edit modal
    @notify(
      type: 'notice'
      msg:  __('Edit functionality not yet implemented')
    )

  deleteApproval: (e) =>
    e.preventDefault()
    approval_id = $(e.currentTarget).data('approval-id')
    
    @ajax(
      id:          'delete_approval'
      type:        'DELETE'
      url:         "#{@apiPath}/tickets/#{@ticket_id}/approvals/#{approval_id}"
      processData: true
      success:     @approvalSuccess
      error:       @approvalError
    )

  approvalSuccess: (data, status, xhr) =>
    @notify(
      type: 'success'
      msg:  __('Approval updated successfully')
    )
    # Reload approvals from backend
    @loadApprovals()
    @callback() if @callback

  approvalError: (xhr, status, error) =>
    @notify(
      type: 'error'
      msg:  __('Failed to update approval')
    )

  refresh: =>
    if @callback
      @callback()
