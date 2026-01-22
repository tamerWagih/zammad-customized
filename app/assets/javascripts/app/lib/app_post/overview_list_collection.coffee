class _Singleton
  constructor: ->
    @overview = {}
    @callbacks = {}
    @fetchActive = {}
    @counter = 0

    App.Event.bind 'ticket_overview_list', (data) =>
      if data.assets
        App.Collection.loadAssets(data.assets)
        delete data.assets
      # Use link as the key for OverviewListCollection (works for both standard and custom overviews)
      # Fallback to view if link is not available (for backwards compatibility)
      overview_key = data.overview.link || (if typeof data.overview.view is 'string' then data.overview.view else data.overview.link || data.overview.id)
      if !@overview[overview_key]
        @overview[overview_key] = {}
      @overview[overview_key] = data
      @callback(overview_key, data)

    App.Event.bind 'auth:logout', (data) =>
      @clear(data)

  get: (view) ->
    @overview[view]

  bind: (view, callback, init = true) ->
    @counter += 1
    @callbacks[@counter] =
      view: view
      callback: callback

    # start init call if needed
    if init
      if @overview[view] is undefined
        @fetch(view)
      else
        @callback(view, @overview[view])

    @counter

  unbind: (counter) ->
    delete @callbacks[counter]

  fetch: (view) =>
    # Always use AJAX for explicit fetches to get immediate results
    # WebSocket event 'ticket_overview_list' only triggers reset() on the backend
    # which sets a cache flag but does NOT return data immediately.
    # The actual data push happens asynchronously on the next polling cycle (TTL-based).
    # For new custom filters, this means the user would wait indefinitely.
    # AJAX ensures we get immediate data when explicitly requesting a view.
    # Realtime updates still work via the WebSocket push mechanism (ticket_overview_list event binding above).
    throw 'No view to fetch list!' if !view

    App.OverviewIndexCollection.fetch()
    return if @fetchActive[view]
    @fetchActive[view] = true
    App.Ajax.request(
      id:   "ticket_overview_#{view}"
      type: 'GET'
      url:  "#{App.Config.get('api_path')}/ticket_overviews"
      data:
        view: view
      processData: true,
      success: (data) =>
        @fetchActive[view] = false
        if data.assets
          App.Collection.loadAssets(data.assets)
          delete data.assets
        # Determine the key to use for storing data and invoking callbacks
        # Use overview_key from response if available, otherwise use the original view parameter
        overview_key = view
        if data.index && data.index.overview
          # Use link as the key for OverviewListCollection
          # Fallback to view if link is not available (for backwards compatibility)
          overview_key = data.index.overview.link || (if typeof data.index.overview.view is 'string' then data.index.overview.view else data.index.overview.link || data.index.overview.id)
          @overview[overview_key] = data.index
        # CRITICAL: Use overview_key (not view) to invoke callback
        # This ensures callbacks registered with overview_key will fire when data arrives
        @callback(overview_key, data.index)
      error: =>
        @fetchActive[view] = false
    )

  trigger: (view) =>
    @callback(view, @get(view))

  callback: (view, data) =>
    for counter, meta of @callbacks
      if meta.view is view
        callback = ->
          meta.callback(data)
        App.QueueManager.add('ticket_overviews', callback)
        App.QueueManager.run('ticket_overviews')

  clear: =>
    @overview = {}
    @callbacks = {}
    @fetchActive = {}
    @counter = 0

class App.OverviewListCollection
  _instance = new _Singleton

  @get: (view) ->
    if _instance == undefined
      _instance ?= new _Singleton
    _instance.get(view)

  @bind: (view, callback, init) ->
    if _instance == undefined
      _instance ?= new _Singleton
    _instance.bind(view, callback, init)

  @unbind: (counter) ->
    if _instance == undefined
      _instance ?= new _Singleton
    _instance.unbind(counter)

  @fetch: (view) ->
    if _instance == undefined
      _instance ?= new _Singleton
    _instance.fetch(view)

  @trigger: (view) ->
    if _instance == undefined
      _instance ?= new _Singleton
    _instance.trigger(view)
