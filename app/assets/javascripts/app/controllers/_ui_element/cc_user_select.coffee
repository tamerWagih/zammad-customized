# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    new App.CcUserSelect(attribute: attribute, params: params).element()

class App.CcUserSelect extends Spine.Controller
  elements:
    '.js-search': 'searchInput'
    '.js-results': 'resultsContainer'
    '.js-loading': 'loadingIndicator'
    '.js-selected': 'selectedContainer'

  events:
    'input .js-search': 'onSearchInput'
    'click .js-search': 'onSearchClick'
    'click .js-user-option': 'onUserSelect'
    'click .js-remove-user': 'onUserRemove'
    'click .js-clear': 'clearAll'
    'click .js-load-more': 'loadMoreUsers'
    'keydown .js-search': 'onSearchKeydown'

  className: 'form-control cc-user-select'

  constructor: ->
    super
    @attribute = @options.attribute
    @params = @options.params || {}
    @selectedUsers = []
    @allUsers = []
    @searchTimeout = null
    @currentPage = 1
    @hasMore = true
    @isLoading = false
    @render()

  element: =>
    @el

  render: ->
    @html App.view('ui_element/cc_user_select')(
      attribute: @attribute
      selectedUsers: @selectedUsers
    )
    # Don't load users immediately - wait for user interaction
    @showInitialState()

  loadUsers: (query = '', page = 1, append = false) ->
    return if @isLoading
    @isLoading = true
    @showLoading()

    # Get Agent and Customer role IDs (like approval modal)
    agentRole = App.Role.findByAttribute('name', 'Agent')
    customerRole = App.Role.findByAttribute('name', 'Customer')
    
    if !agentRole || !customerRole
      # Fallback to App.User.all() if roles not found
      @loadUsersFallback(query, page, append)
      return

    # Use AJAX call like approval modal for better performance
    searchParams = {
      role_ids: [agentRole.id, customerRole.id]
      limit: 50
      page: page
      full: false
    }
    
    if query && query.trim() isnt ''
      searchParams.query = query

    # Make AJAX call to backend (like approval modal)
    App.Ajax.request(
      id: 'cc_users_search'
      type: 'GET'
      url: "#{App.Config.get('api_path')}/users/search"
      data: searchParams
      processData: true
      success: (data, status, xhr) =>
        @handleUsersResponse(data, xhr, append)
      error: (xhr, status, error) =>
        console.log('CC User Search Error:', xhr, status, error)
        # Fallback to local search
        @loadUsersFallback(query, page, append)
    )

  loadUsersFallback: (query = '', page = 1, append = false) ->
    # Fallback: Use the same pattern as approval widget - get all users and filter
    allUsers = []
    for user_id, user of App.User.all()
      if user.active && (user.permissions?('ticket.agent') || user.permissions?('ticket.customer'))
        # Exclude current user (can't CC yourself)
        if user.id isnt App.User.current()?.id
          allUsers.push(user)

    # Apply search filter if query provided
    if query && query.trim() isnt ''
      queryLower = query.toLowerCase()
      allUsers = allUsers.filter (user) ->
        name = user.displayName().toLowerCase()
        email = (user.email || '').toLowerCase()
        login = (user.login || '').toLowerCase()
        return name.includes(queryLower) or email.includes(queryLower) or login.includes(queryLower)

    # Sort by name (following approval pattern)
    allUsers = _.sortBy(allUsers, (user) -> user.displayName())

    # Simulate pagination for large datasets
    pageSize = 50
    startIndex = (page - 1) * pageSize
    endIndex = startIndex + pageSize
    pageUsers = allUsers.slice(startIndex, endIndex)
    
    # Simulate response structure
    responseData = {
      users: pageUsers
      total_count: allUsers.length
    }
    
    @handleUsersResponse(responseData, { getResponseHeader: -> allUsers.length }, append)

  handleUsersResponse: (data, xhr, append = false) ->
    users = if Array.isArray(data) then data else (data?.users || [])
    total_count = parseInt(xhr?.getResponseHeader('X-Paginate-Total') || data?.total_count || users.length)

    # Filter users (exclude current user and inactive users) - like approval modal
    current_user_id = App.User.current()?.id
    eligible_users = users.filter (user) ->
      return false if user.id is current_user_id  # Exclude current user
      return false if user.active is false        # Exclude inactive users
      true

    if append
      @allUsers = @allUsers.concat(eligible_users)
    else
      @allUsers = eligible_users

    @hasMore = (@currentPage * 50) < total_count
    @renderResults()
    @hideLoading()
    @isLoading = false

  renderResults: ->
    # Remove already selected users from results
    selected_ids = @selectedUsers.map((user) -> user.id)
    available_users = @allUsers.filter (user) ->
      !selected_ids.includes(user.id)
    
    @resultsContainer.html App.view('ui_element/cc_user_select_results')(
      users: available_users
      hasMore: @hasMore
    )

  renderSelected: ->
    @selectedContainer.html App.view('ui_element/cc_user_select_selected')(
      selectedUsers: @selectedUsers
    )

  onSearchClick: (e) ->
    # Load users on first click (like approval modal)
    if @allUsers.length is 0 and !@isLoading
      @loadUsers('', 1, false)

  onSearchInput: (e) ->
    query = $(e.target).val()
    
    # Load users on first interaction (like approval modal)
    if @allUsers.length is 0 and !@isLoading
      @loadUsers(query, 1, false)
      return
    
    # Clear previous timeout
    clearTimeout(@searchTimeout) if @searchTimeout
    
    # Debounce search
    @searchTimeout = setTimeout =>
      @currentPage = 1
      @allUsers = []
      @loadUsers(query, 1, false)
    , 300

  onUserSelect: (e) ->
    user_id = parseInt($(e.currentTarget).data('user-id'))
    user = @allUsers.find((u) -> u.id == user_id)
    
    if user && !@selectedUsers.find((u) -> u.id == user_id)
      @selectedUsers.push(user)
      @renderSelected()
      @renderResults()
      @updateHiddenInput()

  onUserRemove: (e) ->
    user_id = parseInt($(e.currentTarget).data('user-id'))
    @selectedUsers = @selectedUsers.filter((u) -> u.id != user_id)
    @renderSelected()
    @renderResults()
    @updateHiddenInput()

  clearAll: ->
    @selectedUsers = []
    @renderSelected()
    @renderResults()
    @updateHiddenInput()

  onSearchKeydown: (e) ->
    # Handle Enter key to select first result
    if e.keyCode == 13
      e.preventDefault()
      firstOption = @resultsContainer.find('.js-user-option').first()
      if firstOption.length
        firstOption.click()

  loadMoreUsers: ->
    return if @isLoading || !@hasMore
    @currentPage += 1
    query = @searchInput.val() || ''
    @loadUsers(query, @currentPage, true)

  showLoading: ->
    @loadingIndicator.show()

  hideLoading: ->
    @loadingIndicator.hide()

  showError: (message) ->
    @resultsContainer.html """
      <div class="alert alert-danger">
        <i class="icon icon-warning"></i>
        #{message}
      </div>
    """
    @hideLoading()
    @isLoading = false

  showInitialState: ->
    # Show initial state like approval modal
    @resultsContainer.html """
      <div class="initial-state">
        <div class="text-muted">
          <i class="icon icon-search"></i>
          <%- @T('Start typing to search for users...') %>
        </div>
      </div>
    """

  updateHiddenInput: ->
    # Update the hidden input with selected user IDs
    user_ids = @selectedUsers.map((user) -> user.id)
    @el.find('input[name="' + @attribute.name + '"]').val(JSON.stringify(user_ids))
