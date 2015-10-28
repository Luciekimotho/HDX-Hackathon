class ChapinUtils
  constructor: (options) ->
    # required
    @mediator = options.mediator
    @site = options.site
    @enable = options.enable
    @verbosity = options.verbosity
    @urls = options.urls

    # optional
    @time = options?.time
    @localhost = options?.localhost
    @ua = options?.ua
    @google = options?.google

  JQUERY_EVENTS: """
    blur focus focusin focusout load resize scroll unload click dblclick
    mousedown mouseup  mousemove mouseover mouseout mouseenter mouseleave
    change select submit keydown keypress keyup error
    """

  init: =>
    Minilog
      .enable()
      .pipe new Minilog.backends.jQuery
        url: @urls.logger
        interval: @log_interval

    @logger = Minilog @site.id
    @log_interval = @time?.logger ? 5000
    @scroll_time = @time?.scroll ? 750
    @analytics = @google?.analytics
    @google_analytics_id = "#{@analytics?.id}-#{@analytics?.site_number}"

  initGA: =>
    if @localhost
      cookie_domain = {cookieDomain: 'none'}
    else
      cookie_domain = 'auto'

    ga 'create', @google_analytics_id, cookie_domain
    ga 'require', 'displayfeatures'

  changeURL: (pageId, params=null) ->
    url = if params? then "#{pageId}?#{$.param(params)}" else pageId
    Backbone.history.navigate url, trigger: false

  smoothScroll: (postion) =>
    $('html, body').animate scrollTop: postion, @scroll_time, 'linear'

  filterCollection: (collection, query) ->
    if query?.filterby?.key and query?.filterby?.value
      new Chaplin.Collection collection.filter (model) ->
        model.get(query.filterby.key) is JSON.parse query.filterby.value
    else
      collection

  makeFilterer: (filterby, query) ->
    (model) ->
      if query and query.filterby?.key and query.filterby?.value
        filter1 = model.get(query.filterby.key) is query.filterby.value
      else
        filter1 = true

      return filter1 unless filterby?.key and filterby?.value

      if filterby?.token
        model_values = _.pluck(model.get(filterby.key), filterby.token)
      else
        model_values = model.get(filterby.key)

      if _.isArray(model_values)
        model_slugs = _.map(model_values, (value) -> s.slugify value)
        filter2 = filterby.value in model_slugs
      else
        filter2 = filterby.value is s.slugify(model_values)

      filter1 and filter2

  makeComparator: (sortby, orderby) =>
    (model) -> (if orderby is 'asc' then 1 else -1) * model.get sortby

  getTags: (collection, options) ->
    return [] unless collection.length > 0
    options = options ? {}
    attr = options.attr ? 'k:tags'
    sortby = options.sortby ? 'count'
    orderby = if options.orderby is 'asc' then 1 else -1
    token = options.token
    n = options.n
    start = options.start ? 0

    flattened = _.flatten collection.pluck attr
    # ['a', 'c', 'B', 'b', 'b b', 'c'] or if tokenized
    # [{token: 'a'}, {token: 'c'}, {token: 'B'}, {token: 'b'}, {token: 'b b'}]
    all = if token then _.pluck(flattened, token) else flattened
    # ['a', 'c', 'B', 'b', 'b b', 'c']
    counts = _.countBy all, (name) -> name?.toLowerCase()
    # {a: 1, c: 2, b: 2, b b: 1}
    collected = ({name, slug: s.slugify(name), count} for name, count of counts)
    # [
    #   {name: 'a', slug: 'a', count: 1},
    #   {name: 'c', slug: 'c', count: 2},
    #   {name: 'b', slug: 'b', count: 2},
    #   {name: 'b b', slug: 'b-b', count: 1},
    # ]
    cleaned = _.reject collected, (tag) -> tag.name in ['', 'undefined']
    presorted = _.sortBy cleaned, 'name'
    # [
    #   {name: 'a', slug: 'a', count: 1},
    #   {name: 'b', slug: 'b', count: 2},
    #   {name: 'b b', slug: 'b-b', count: 2},
    #   {name: 'c', slug: 'c', count: 1},
    # ]
    sorted = _.sortBy(presorted, (name) -> orderby * name[sortby])
    # [
    #   {name: 'b', slug: 'b', count: 2},
    #   {name: 'b b', slug: 'b-b', count: 2},
    #   {name: 'a', slug: 'a', count: 1},
    #   {name: 'c', slug: 'c', count: 1},
    # ]
    if n then sorted[start...start + n] else sorted[start..]

  checkIDs: ->
    $('[id]').each ->
      ids = $('[id="' + this.id + '"]')
      if (ids.length > 1 and ids[0] is this)
        console.warn "Multiple IDs for ##{this.id}"

  # Logging helper
  # ---------------------
  _getPriority: (level) ->
    switch level
      when 'debug' then 1
      when 'info' then 2
      when 'warn' then 3
      when 'error' then 4
      when 'pageview' then 5
      when 'screenview' then 6
      when 'event' then 7
      when 'transaction' then 8
      when 'item' then 9
      when 'social' then 10
      else 0

  log: (message, level='debug', options) =>
    priority = @_getPriority level
    url = @mediator.url
    options = options ? {}

    local_enabled = @enable.logger.local
    remote_enabled = @enable.logger.remote
    tracking_enabled = @analytics?.id and @enable.tracker

    local_priority = priority >= @verbosity.logger.local
    remote_priority = priority >= @verbosity.logger.remote
    tracker_priority = priority >= @verbosity.tracker

    log_local = local_enabled and local_priority
    log_remote = remote_enabled and remote_priority
    track = tracking_enabled and tracker_priority

    if log_local and priority >= @verbosity.tracker
      console.log "#{level} for #{url}"
    else if log_local
      console.log message

    if log_remote or track
      user_options =
        time: (new Date()).getTime()
        user: @mediator?.user?.get('email') ? @mediator?.user?.email

    if log_remote
      text = JSON.stringify message
      message = if text.length > 512 then "size exceeded" else message
      data = _.extend {message}, user_options
      @logger[level] data

    if track
      ga (tracker) =>
        hit_options =
          v: 1
          tid: @google_analytics_id
          cid: tracker.get 'clientId'
          uid: @mediator?.user?.get('id') ? @mediator?.user?.id
          # uip: ip address
          dr: document.referrer or 'direct'
          ua: @ua
          gclid: @google?.adwords_id
          dclid: @google?.displayads_id
          sr: "#{screen.width}x#{screen.height}"
          vp: "#{$(window).width()}x#{$(window).height()}"
          t: level
          an: @site.title
          aid: @site.id
          av: @site.version
          dp: url
          dh: document.location.hostname
          dt: message

        switch level
          when 'event'
            hit_options = _.extend hit_options,
              ec: options.category
              ea: options.action
              ev: options?.value
              el: options?.label ? 'N/A'

          when 'transaction'
            hit_options = _.extend hit_options,
              ti: options.trxn_id
              tr: options?.amount ? 0
              ts: options?.shipping ? 0
              tt: options?.tax ? 0
              cu: options?.cur ? 'USD'
              ta: options?.affiliation ? 'N/A'

          when 'item'
            hit_options = _.extend hit_options,
              ti: options.trxn_id
              in: options.name
              ip: options?.amount ? 0
              iq: options?.qty ? 1
              cu: options?.cur ? 'USD'
              ic: options?.sku ? 'N/A'
              iv: options?.category ? 'N/A'

          when 'social'
            hit_options = _.extend hit_options,
              sn: options?.network ? 'facebook'
              sa: options?.action ? 'like'
              st: options?.target ? url

        if level is 'experiment'
          hit_options = _.extend hit_options,
            xid: options.xid
            xvar: options?.xvar ? 'A'

        data = _.extend options, user_options, hit_options
        $.post @urls.tracker, data

if module?.exports
  # Commonjs
  exports = module.exports = ChapinUtils
else if exports?
  # Node.js
  exports.ChapinUtils = ChapinUtils
else if define?.amd?
  # Requirejs
  define [], -> ChapinUtils
  @ChapinUtils = ChapinUtils
else if window? or require?
  # Browser
  window.ChapinUtils = ChapinUtils
else
  @ChapinUtils = ChapinUtils
