# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class App.WidgetCc extends App.Controller
  editMode: false
  pendingRefresh: false
  templateName: 'widget/cc'
  elements:
    '.js-addCcLabel': 'addCcLabel'
    '.js-ccSelect': 'ccSelect'

  events:
    'click .js-addCcLabel': 'showSelect'
    'click .js-delete': 'onRemoveCc'
    'change .js-ccSelect': 'onCcSelectChange'

  constructor: ->
    super

    # Store original CC user IDs for comparison
    @originalCcUserIds = []
    @pendingAdds = []
    @pendingRemoves = []

    # If CCs are given, use them directly
    if @ccs
      @localCcs = _.clone(@ccs)
      @originalCcUserIds = @localCcs.map((cc) -> parseInt(cc.user_id))
      @render()
      return

    @fetch()

  fetch: =>
    @pendingRefresh = false
    @ajax(
      id:   "ccs_#{@ticket.id}"
      type: 'GET'
      url:  "#{@apiPath}/tickets/#{@ticket.id}/ticket_ccs"
      processData: true
      success: (data, status, xhr) =>
        @localCcs = data.ticketCcs || []
        @originalCcUserIds = @localCcs.map((cc) -> parseInt(cc.user_id))
        App.Collection.loadAssets(data.assets) if data.assets
        @render()
    )

  reload: (ccs) =>
    if @editMode
      @pendingRefresh = true
      return
    @localCcs = _.clone(ccs || [])
    @originalCcUserIds = @localCcs.map((cc) -> parseInt(cc.user_id))
    @render()

  render: =>
    return if @lastLocalCcs && _.isEqual(@lastLocalCcs, @localCcs)
    @lastLocalCcs = _.clone(@localCcs)

    # Get current user ID to exclude from display
    currentUserId = App.Session.get('id')

    # Filter out current user from display
    displayCcs = @localCcs.filter((cc) -> parseInt(cc.user_id) != parseInt(currentUserId))

    @html App.view(@templateName)(
      ccs: displayCcs || []
      editable: @editable
      ticket: @ticket
    )

    # Initialize CC select if editable
    if @editable
      @initCcSelect()

  initCcSelect: =>
    # Hide select initially
    @ccSelect?.addClass('hide')

    # Get current CC user IDs (excluding current user)
    currentUserId = App.Session.get('id')
    currentCcUserIds = @localCcs
      .map((cc) -> parseInt(cc.user_id))
      .filter((id) -> id != parseInt(currentUserId))

    # Create CC user select element
    attribute = {
      name: 'cc_user_ids'
      display: __('CC')
      tag: 'cc_user_select'
      multiple: true
      limit: 50
      null: true
      value: currentCcUserIds
    }

    params = {
      cc_user_ids: currentCcUserIds
      ticket_id: @ticket.id
    }

    # Render CC user select
    ccSelectElement = App.UiElement.cc_user_select.render(attribute, params)
    
    # Replace the placeholder with actual select
    if @ccSelect && ccSelectElement
      @ccSelect.replaceWith(ccSelectElement)
      @ccSelect = @$('.js-ccSelect')
      
      # Bind change event
      @ccSelect.on('change', @onCcSelectChange)

  showSelect: (e) =>
    e.preventDefault()
    return unless @editable

    @addCcLabel.addClass('hide')
    @ccSelect?.removeClass('hide').trigger('focus')
    @editMode = true

  hideSelect: =>
    @addCcLabel.removeClass('hide')
    @ccSelect?.addClass('hide')
    @editMode = false

  onCcSelectChange: (e) =>
    return unless @editable

    # Get selected user IDs from the select
    selectedUserIds = []
    @ccSelect.find('option:selected').each ->
      userId = $(this).val()
      selectedUserIds.push(parseInt(userId)) if userId

    # Get current CC user IDs (excluding current user)
    currentUserId = App.Session.get('id')
    currentCcUserIds = @localCcs
      .map((cc) -> parseInt(cc.user_id))
      .filter((id) -> id != parseInt(currentUserId))

    # Calculate adds and removes
    @pendingAdds = selectedUserIds.filter((id) -> !currentCcUserIds.includes(id))
    @pendingRemoves = currentCcUserIds.filter((id) -> !selectedUserIds.includes(id))

    # Update local state for display (optimistic update)
    # Remove users that are being removed
    @localCcs = @localCcs.filter((cc) ->
      ccUserId = parseInt(cc.user_id)
      return false if @pendingRemoves.includes(ccUserId)
      return true
    )

    # Add placeholder entries for users being added (will be replaced with real data after save)
    for userId in @pendingAdds
      unless @localCcs.find((cc) -> parseInt(cc.user_id) == userId)
        @localCcs.push({
          user_id: userId
          user_name: __('Loading...')
          id: null  # Temporary, will get real ID after save
        })

    @render()

    # Mark form as changed
    App.Event.trigger('ui::ticket::cc::changed', {
      ticket_id: @ticket.id
      adds: @pendingAdds
      removes: @pendingRemoves
    })

  onRemoveCc: (e) =>
    e.preventDefault()
    return unless @editable

    ccElement = $(e.currentTarget).closest('.js-cc-item')
    userId = parseInt(ccElement.data('user-id'))

    # Add to pending removes
    unless @pendingRemoves.includes(userId)
      @pendingRemoves.push(userId)

    # Remove from local state
    @localCcs = @localCcs.filter((cc) -> parseInt(cc.user_id) != userId)

    @render()

    # Mark form as changed
    App.Event.trigger('ui::ticket::cc::changed', {
      ticket_id: @ticket.id
      adds: @pendingAdds
      removes: @pendingRemoves
    })

  # Get pending CC changes for batch update
  getPendingChanges: =>
    {
      adds: @pendingAdds || []
      removes: @pendingRemoves || []
    }

  # Clear pending changes after successful update
  clearPendingChanges: =>
    @pendingAdds = []
    @pendingRemoves = []
    @originalCcUserIds = @localCcs.map((cc) -> parseInt(cc.user_id))

