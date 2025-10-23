# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_select
  @render: (attribute, params = {}) ->
    # Lazy loading implementation: Load users only when dropdown is opened
    # This prevents performance issues with large user bases
    # Includes: ONLY Agents and Customers (for ticket sharing)
    # Excludes: The current user (ticket creator) and admins/other roles
    # Note: CC grants ticket access regardless of group permissions
    
    attribute.tag = 'searchable_select'
    attribute.multiple = true
    attribute.nulloption = true
    attribute.placeholder = __('Click to search for users to CC...')
    # Remove relation to prevent conflict with API loading
    delete attribute.relation
    # Start with empty options - load only when needed
    attribute.options = {}
    
    # Add performance hints for large datasets
    if params.organization_size && params.organization_size > 1000
      attribute.placeholder = __('Large organization detected. Type to search users...')
      console.log "[CC_USERS] Large organization mode enabled"

    # Render the searchable select first (empty state)
    element = App.UiElement.searchable_select.render(attribute, params)
    
    # Store references for lazy loading and caching
    element.data('cc-lazy-load-needed', true)
    element.data('cc-search-query', '')
    element.data('cc-current-page', 1)
    element.data('cc-has-more-pages', false)
    element.data('cc-search-cache', {})  # Cache for search results
    element.data('cc-last-search-time', 0)  # Prevent excessive API calls

    # Bind lazy loading to dropdown events
    @bindLazyLoading(element, attribute, params)

    console.log "[CC_USERS] CC dropdown initialized with lazy loading"

    # Return the element (empty state, will load on demand)
    element

  # Get the selected group ID from the form or attribute (for potential future use)
  @getSelectedGroupId: (attribute) ->
    # First check if group_id was passed in the attribute (from form handler)
    if attribute && attribute.group_id
      console.log "[CC_USERS] Using group_id from attribute:", attribute.group_id
      return attribute.group_id

    # Try to find the group_id field in the form (for debugging)
    form = $('form')
    if form.length > 0
      groupField = form.find('[data-attribute-name="group_id"] select')
      if groupField.length == 0
        groupField = form.find('[name="group_id"]')
      if groupField.length == 0
        groupField = form.find('select[data-attribute-name*="group"]')

      if groupField.length > 0
        selectedValue = groupField.val()
        console.log "[CC_USERS] Found group field with value:", selectedValue
        return selectedValue if selectedValue && selectedValue != ''

    # If no form or no group selected, return null
    console.log "[CC_USERS] No group selected or form not found"
    null

  # Bind lazy loading and search functionality
  @bindLazyLoading: (element, attribute, params) ->
    # Find the SearchableSelect instance
    searchableSelectInstance = element.data('controller')

    if searchableSelectInstance
      # Override the onFocus and onClick methods to trigger lazy loading
      originalOnFocus = searchableSelectInstance.onFocus
      originalOnClick = searchableSelectInstance.onClick
      originalOnInput = searchableSelectInstance.onInput

      searchableSelectInstance.onFocus = (event) =>
        console.log "[CC_USERS] Dropdown focused, checking if lazy load needed"
        @loadUsersIfNeeded(element, attribute, params)
        originalOnFocus?.call(searchableSelectInstance, event)

      searchableSelectInstance.onClick = (event) =>
        console.log "[CC_USERS] Dropdown clicked, checking if lazy load needed"
        @loadUsersIfNeeded(element, attribute, params)
        originalOnClick?.call(searchableSelectInstance, event)

      # Override onInput for search-as-you-type with caching and debouncing
      searchableSelectInstance.onInput = (event) =>
        searchQuery = event.target.value.trim()
        console.log "[CC_USERS] Search input changed:", searchQuery

        # Update search query
        element.data('cc-search-query', searchQuery)
        element.data('cc-current-page', 1)  # Reset to first page on new search

        # Debounce search requests (300ms delay)
        clearTimeout(element.data('cc-search-timeout'))
        searchTimeout = setTimeout =>
          # Check cache first
          searchCache = element.data('cc-search-cache')
          cacheKey = "#{searchQuery}_1"

          if searchCache[cacheKey]
            console.log "[CC_USERS] Loading from cache:", cacheKey
            @updateDropdownOptions(element, attribute, params, searchCache[cacheKey])
          else
            # Load from API
            if searchQuery.length > 0
              @loadUsers(element, attribute, params, searchQuery, 1)
            else
              @loadUsers(element, attribute, params, '', 1)
        , 300

        element.data('cc-search-timeout', searchTimeout)
        originalOnInput?.call(searchableSelectInstance, event)

      # Add scroll handler for "load more" functionality
      dropdownElement = element.find('.dropdown-menu')
      if dropdownElement.length > 0
        dropdownElement.on 'scroll.cc_load_more', (event) =>
          @handleScrollForMore(element, attribute, params)

    else
      # Fallback: bind to element events
      element.on 'focus.searchable_select', (event) =>
        console.log "[CC_USERS] Element focused, loading users"
        @loadUsersIfNeeded(element, attribute, params)

      element.on 'click.searchable_select', (event) =>
        console.log "[CC_USERS] Element clicked, loading users"
        @loadUsersIfNeeded(element, attribute, params)

  # Load users only when needed
  @loadUsersIfNeeded: (element, attribute, params) ->
    if element.data('cc-lazy-load-needed')
      console.log "[CC_USERS] Lazy loading triggered, fetching users"
      searchQuery = element.data('cc-search-query') || ''
      page = element.data('cc-current-page') || 1
      @loadUsers(element, attribute, params, searchQuery, page)

  # Load users from API with search and pagination
  @loadUsers: (element, attribute, params, searchQuery = '', page = 1) ->
    # Show loading state
    attribute.placeholder = __('Loading users...')
    element.data('cc-lazy-load-needed', false)

    # Build API URL with search and pagination (no group filtering)
    apiUrl = "#{App.Config.get('api_path')}/tickets/cc_users"
    apiUrl += "?search=#{encodeURIComponent(searchQuery)}" if searchQuery
    apiUrl += "&page=#{page}" if page > 1

    console.log "[CC_USERS] Loading users from:", apiUrl

    App.Ajax.request(
      type: 'GET'
      url: apiUrl
      async: true
      success: (data) =>
        # Handle both old format (array) and new format (object with users array)
        users = if data.users then data.users else data
        pagination = data.pagination || {}

        console.log "[CC_USERS] Loaded #{users?.length || 0} users"
        console.log "[CC_USERS] Pagination:", pagination
        
        options = {}
        if users && users.length > 0
          for user in users
            display_name = "#{user.firstname || ''} #{user.lastname || ''}".trim()
            display_name = user.login if display_name == ''
            display_name = user.email if !display_name
            display_name = "User ##{user.id}" if !display_name

            # Add user type indicator for clarity (agents and customers only)
            # Handle the case where backend double-checks admin exclusion
            user_type_label = switch user.user_type
              when 'agent' then __('[Agent]')
              when 'customer' then __('[Customer]')
              when 'admin_excluded' then __('[Admin - Excluded]')
              else __('[User]')

            if user.email && display_name != user.email
              display_name += " (#{user.email})"
            display_name += " #{user_type_label}"

            options[user.id] = display_name

        # Update element data for pagination
        element.data('cc-current-page', pagination.current_page || 1)
        element.data('cc-has-more-pages', pagination.has_next_page || false)

        # Cache the results (with cleanup for memory management)
        searchCache = element.data('cc-search-cache')
        cacheKey = "#{searchQuery}_#{page}"

        # Clean cache if it gets too large (max 50 entries)
        if Object.keys(searchCache).length > 50
          console.log "[CC_USERS] Cleaning cache, too many entries"
          # Keep only recent entries (last 30)
          cacheKeys = Object.keys(searchCache)
          cacheKeys.sort (a, b) =>
            (searchCache[a].timestamp || 0) - (searchCache[b].timestamp || 0)
          # Keep only the 30 most recent
          keysToRemove = cacheKeys.slice(0, cacheKeys.length - 30)
          keysToRemove.forEach (key) -> delete searchCache[key]

        searchCache[cacheKey] = options
        searchCache[cacheKey].timestamp = Date.now()
        searchCache[cacheKey].user_types = users.map((u) -> u.user_type).uniq() if users
        element.data('cc-search-cache', searchCache)
        element.data('cc-last-search-time', Date.now())

        # Update options and re-render
        @updateDropdownOptions(element, attribute, params, options)

        console.log "[CC_USERS] Successfully loaded and cached CC dropdown results"

        # Show message if no users found
        if Object.keys(options).length == 0
          attribute.placeholder = __('No agents or customers found for CC.')
          App.Notice.info(__('No agents or customers found for CC. Only agents and customers can be CC\'d on tickets (administrators are excluded).'))

        # Check for admin users that were excluded
        excluded_admins = users.filter (u) -> u.user_type == 'admin_excluded'
        if excluded_admins.length > 0
          console.log "[CC_USERS] Excluded #{excluded_admins.length} admin users from CC list: #{excluded_admins.map((u) -> u.login).join(', ')}"
        
      error: (xhr) =>
        console.error '[CC_USERS] Failed to load CC users:', xhr
        console.error '[CC_USERS] Error status:', xhr.status
        console.error '[CC_USERS] Error response:', xhr.responseText

        # Handle different types of errors
        if xhr.status == 403
          # Permission error - user doesn't have agent or customer permissions
          attribute.placeholder = __('You need agent or customer permissions to CC users')
          attribute.options = {}
          App.Notice.error(__('You need agent or customer permissions to CC users on tickets. Please contact your administrator.'))
        else
          # Other errors (network, server, etc.)
          attribute.placeholder = __('Error loading users - please refresh')
          attribute.options = {}
          App.Notice.error(__('Failed to load CC users. Please refresh the page and try again.'))

        # Reset lazy loading flag so it can retry
        element.data('cc-lazy-load-needed', true)
    )

  # Update dropdown options and re-render
  @updateDropdownOptions: (element, attribute, params, options) ->
    attribute.options = options
    attribute.placeholder = __('Search for users to CC...')

    # Try to update the SearchableSelect instance
    searchableSelectInstance = element.data('controller')

    if searchableSelectInstance
      if searchableSelectInstance.renderElement
        console.log "[CC_USERS] Re-rendering SearchableSelect with new options"
        searchableSelectInstance.renderElement()
      else if searchableSelectInstance.render
        console.log "[CC_USERS] Re-rendering SearchableSelect"
        searchableSelectInstance.render()
    else
      # Fallback: re-render the entire element
      console.log "[CC_USERS] Re-rendering entire element"
      newElement = App.UiElement.searchable_select.render(attribute, params)
      element.replaceWith(newElement)

  # Get the selected group ID from the form or attribute
  @getSelectedGroupId: (attribute) ->
    # First check if group_id was passed in the attribute (from form handler)
    if attribute && attribute.group_id
      console.log "[CC_USERS] Using group_id from attribute:", attribute.group_id
      return attribute.group_id

    # Try to find the group_id field in the form
    form = $('form')
    if form.length > 0
      # Look for group_id field by different selectors
      groupField = form.find('[data-attribute-name="group_id"] select')
      if groupField.length == 0
        groupField = form.find('[name="group_id"]')
      if groupField.length == 0
        groupField = form.find('select[data-attribute-name*="group"]')

      if groupField.length > 0
        selectedValue = groupField.val()
        console.log "[CC_USERS] Found group field with value:", selectedValue
        return selectedValue if selectedValue && selectedValue != ''

    # If no form or no group selected, return null (will show all accessible groups)
    console.log "[CC_USERS] No group selected or form not found"
    null

  # Handle scroll events for loading more users
  @handleScrollForMore: (element, attribute, params) ->
    dropdownElement = element.find('.dropdown-menu')
    return unless dropdownElement.length > 0

    # Check if we're near the bottom (within 100px)
    scrollTop = dropdownElement.scrollTop()
    scrollHeight = dropdownElement.prop('scrollHeight')
    clientHeight = dropdownElement.prop('clientHeight')

    # Load more if scrolled within 100px of bottom and more pages available
    if (scrollTop + clientHeight >= scrollHeight - 100) && element.data('cc-has-more-pages')
      currentPage = element.data('cc-current-page') || 1
      searchQuery = element.data('cc-search-query') || ''

      console.log "[CC_USERS] Loading more users - page #{currentPage + 1}"

      # Load next page
      @loadUsers(element, attribute, params, searchQuery, currentPage + 1)

  # Load more users (public method for manual triggering)
  @loadMoreUsers: (element, attribute, params) ->
    if element.data('cc-has-more-pages')
      currentPage = element.data('cc-current-page') || 1
      searchQuery = element.data('cc-search-query') || ''

      console.log "[CC_USERS] Manually loading more users - page #{currentPage + 1}"
      @loadUsers(element, attribute, params, searchQuery, currentPage + 1)
