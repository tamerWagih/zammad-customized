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
    'click .js-user-option': 'onUserSelect'
    'click .js-remove-user': 'onUserRemove'
    'click .js-clear': 'clearAll'
    'click .js-load-more': 'loadMore'
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
    @loadUsers()

  loadUsers: (query = '', page = 1, append = false) ->
    return if @isLoading
    @isLoading = true
    @showLoading()
    
    # Get Agent and Customer role IDs with fallback
    console.log('All roles:', App.Role.all())
    agentRole = App.Role.findByAttribute('name', 'Agent')
    customerRole = App.Role.findByAttribute('name', 'Customer')
    
    console.log('Agent role by name:', agentRole)
    console.log('Customer role by name:', customerRole)
    
    # If roles not found by name, try to find by permissions
    if !agentRole
      agentRoles = App.Role.withPermissions('ticket.agent')
      console.log('Agent roles by permission:', agentRoles)
      agentRole = agentRoles[0] if agentRoles.length > 0
    
    if !customerRole
      customerRoles = App.Role.withPermissions('ticket.customer')
      console.log('Customer roles by permission:', customerRoles)
      customerRole = customerRoles[0] if customerRoles.length > 0
    
    if !agentRole && !customerRole
      @showError('No suitable roles found. Please ensure Agent and Customer roles exist.')
      return
    
    role_ids = [agentRole?.id, customerRole?.id].filter((id) -> id?)
    
    # Make backend API call with search and pagination
    App.Ajax.request(
      id: 'cc_users_search'
      type: 'GET'
      url: "#{App.Config.get('api_path')}/users/search"
      data:
        query: query
        role_ids: role_ids
        limit: 50  # Load 50 at a time for better performance
        page: page
        full: false
      processData: true
      success: (data, status, xhr) =>
        @handleUsersResponse(data, xhr, append)
      error: (xhr, status, error) =>
        console.log('CC User Search Error:', xhr, status, error)
        @showError('Unable to load users. Please try again.')
    )

  handleUsersResponse: (data, xhr, append = false) ->
    console.log('CC User Search Response:', data)
    users = if Array.isArray(data) then data else (data?.users || [])
    total_count = parseInt(xhr?.getResponseHeader('X-Paginate-Total') || users.length)
    
    console.log('Found users:', users.length, 'Total:', total_count)
    
    # Filter users (exclude current user and inactive users)
    current_user_id = App.User.current()?.id
    eligible_users = users.filter (user) ->
      return false if user.id is current_user_id
      return false if user.active is false
      true
    
    console.log('Eligible users after filtering:', eligible_users.length)
    
    if append
      @allUsers = @allUsers.concat(eligible_users)
    else
      @allUsers = eligible_users
    
    @currentPage = parseInt(xhr?.getResponseHeader('X-Paginate-Page') || 1)
    @hasMore = (@currentPage * 50) < total_count
    
    @renderResults()
    @hideLoading()
    @isLoading = false

  renderResults: ->
    # Remove already selected users from results
    selected_ids = @selectedUsers.map((user) -> user.id)
    available_users = @allUsers.filter (user) ->
      !selected_ids.includes(user.id)
    
    # Sort by name
    available_users.sort (a, b) ->
      nameA = (a.firstname || '') + ' ' + (a.lastname || '')
      nameA = a.login if nameA.trim() == ''
      nameA = a.email if !nameA
      nameA = (nameA || '').toLowerCase()
      
      nameB = (b.firstname || '') + ' ' + (b.lastname || '')
      nameB = b.login if nameB.trim() == ''
      nameB = b.email if !nameB
      nameB = (nameB || '').toLowerCase()
      
      if nameA < nameB then -1 else if nameA > nameB then 1 else 0

    @resultsContainer.html App.view('ui_element/cc_user_select_results')(
      users: available_users
      hasMore: @hasMore
    )

  renderSelected: ->
    @selectedContainer.html App.view('ui_element/cc_user_select_selected')(
      selectedUsers: @selectedUsers
    )

  onSearchInput: (e) ->
    query = $(e.target).val()
    
    # Clear previous timeout
    clearTimeout(@searchTimeout) if @searchTimeout
    
    # Debounce search to avoid too many API calls
    @searchTimeout = setTimeout =>
      @allUsers = []  # Clear current results
      @currentPage = 1
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

  loadMore: ->
    if @hasMore && !@isLoading
      query = @searchInput.val() || ''
      @loadUsers(query, @currentPage + 1, true)

  updateHiddenInput: ->
    # Update the hidden input with selected user IDs
    user_ids = @selectedUsers.map((user) -> user.id)
    @el.find('input[name="' + @attribute.name + '"]').val(JSON.stringify(user_ids))

  showLoading: ->
    @loadingIndicator.show()
    @resultsContainer.hide()

  hideLoading: ->
    @loadingIndicator.hide()
    @resultsContainer.show()

  showError: (message) ->
    @resultsContainer.html("<div class='alert alert-warning'>#{message}</div>")
    @hideLoading()
    @isLoading = false
