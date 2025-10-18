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
    'keydown .js-search': 'onSearchKeydown'

  className: 'form-control cc-user-select'

  constructor: ->
    super
    @attribute = @options.attribute
    @params = @options.params || {}
    @selectedUsers = []
    @allUsers = []
    @searchTimeout = null
    @render()

  element: =>
    @el

  render: ->
    @html App.view('ui_element/cc_user_select')(
      attribute: @attribute
      selectedUsers: @selectedUsers
    )
    @loadUsers()

  loadUsers: ->
    # Get all agents and customers (following approval pattern)
    users = []
    for user_id, user of App.User.all()
      if user.active && (user.permissions?('ticket.agent') || user.permissions?('ticket.customer'))
        # Exclude current user (can't CC yourself)
        if user.id isnt App.User.current()?.id
          users.push(user)
    
    # Sort by name (following approval pattern)
    @allUsers = _.sortBy(users, (user) -> user.displayName())
    @renderResults()

  renderResults: ->
    # Remove already selected users from results
    selected_ids = @selectedUsers.map((user) -> user.id)
    available_users = @allUsers.filter (user) ->
      !selected_ids.includes(user.id)
    
    @resultsContainer.html App.view('ui_element/cc_user_select_results')(
      users: available_users
    )

  renderSelected: ->
    @selectedContainer.html App.view('ui_element/cc_user_select_selected')(
      selectedUsers: @selectedUsers
    )

  onSearchInput: (e) ->
    query = $(e.target).val().toLowerCase()
    
    # Filter users based on search query
    filtered_users = @allUsers.filter (user) ->
      name = user.displayName().toLowerCase()
      return name.includes(query) or 
             (user.email && user.email.toLowerCase().includes(query)) or
             (user.login && user.login.toLowerCase().includes(query))
    
    # Remove already selected users
    selected_ids = @selectedUsers.map((user) -> user.id)
    available_users = filtered_users.filter (user) ->
      !selected_ids.includes(user.id)
    
    @resultsContainer.html App.view('ui_element/cc_user_select_results')(
      users: available_users
    )

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

  updateHiddenInput: ->
    # Update the hidden input with selected user IDs
    user_ids = @selectedUsers.map((user) -> user.id)
    @el.find('input[name="' + @attribute.name + '"]').val(JSON.stringify(user_ids))
