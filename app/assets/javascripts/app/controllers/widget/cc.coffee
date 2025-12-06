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

    @html App.view(@templateName)(
      ccs: @localCcs || []
      editable: @editable
      ticket: @ticket
    )

    # Don't initialize CC select here - only render when user clicks "Add CC"
    # This prevents empty input from showing

  initCcSelect: =>
    # Check if already initialized
    if @ccSelect && @ccSelect.length > 0
      return

    # Find the placeholder element
    ccSelectPlaceholder = @$('.js-ccSelect')
    return unless ccSelectPlaceholder.length > 0

    # Get current CC user IDs (include current user so values match backend)
    currentCcUserIds = @localCcs.map((cc) -> parseInt(cc.user_id))

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
    if ccSelectElement && ccSelectElement.length > 0
      # Wrap the element in a div with js-ccSelect class to maintain selector
      wrappedElement = $('<div class="js-ccSelect hide"></div>').append(ccSelectElement)
      ccSelectPlaceholder.replaceWith(wrappedElement)
      
      # Store reference to the wrapper (which has the class)
      @ccSelect = @$('.js-ccSelect')
      
      # Ensure it's hidden
      @ccSelect.addClass('hide')
      
      # Find the actual input/select element within for change event
      @ccSelectInput = @ccSelect.find('input, select').first()
      
      # Bind change event on the wrapper (bubbles from input)
      @ccSelect.on('change', @onCcSelectChange)

  showSelect: (e) =>
    e.preventDefault()
    return unless @editable

    # Initialize CC select if not already done
    @initCcSelect() unless @ccSelect && @ccSelect.length > 0

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
    # SearchableAjaxSelect stores values in shadow input as <option> elements for multiple selects
    selectedUserIds = []
    
    # Find shadow input (hidden select with selected options)
    shadowInput = @ccSelect.find('.js-shadow')
    if shadowInput.length > 0 && shadowInput.is('select')
      # For multiple selects, shadow input contains <option> elements with values
      shadowInput.find('option').each ->
        userId = $(this).val()
        selectedUserIds.push(parseInt(userId)) if userId
    else
      # Fallback: find tokens with data-value attribute
      @ccSelect.find('.token[data-value]').each ->
        userId = $(this).attr('data-value')
        selectedUserIds.push(parseInt(userId)) if userId

    # Calculate based on original state (before any pending changes)
    # This ensures we don't have conflicts
    originalCcUserIds = @originalCcUserIds.slice()
    
    # Calculate what should be added (in selected but not in original)
    newAdds = selectedUserIds.filter((id) -> !originalCcUserIds.includes(id))
    # Calculate what should be removed (in original but not in selected)
    newRemoves = originalCcUserIds.filter((id) -> !selectedUserIds.includes(id))
    
    # Initialize pending arrays
    @pendingAdds = @pendingAdds || []
    @pendingRemoves = @pendingRemoves || []
    
    # Resolve conflicts: remove users from pendingAdds if they're now being removed
    @pendingAdds = @pendingAdds.filter((id) -> !newRemoves.includes(id))
    # Resolve conflicts: remove users from pendingRemoves if they're now being added back
    @pendingRemoves = @pendingRemoves.filter((id) -> !newAdds.includes(id))
    
    # Add new adds (not already in pendingAdds)
    for userId in newAdds
      unless @pendingAdds.includes(userId)
        @pendingAdds.push(userId)
    
    # Add new removes (not already in pendingRemoves)
    for userId in newRemoves
      unless @pendingRemoves.includes(userId)
        @pendingRemoves.push(userId)

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

    # Initialize pending arrays if needed
    @pendingAdds = @pendingAdds || []
    @pendingRemoves = @pendingRemoves || []

    # If user is in pendingAdds (was just added), remove from pendingAdds instead of adding to pendingRemoves
    if @pendingAdds.includes(userId)
      @pendingAdds = @pendingAdds.filter((id) -> id != userId)
    else
      # User is in original CC list, add to pendingRemoves
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

