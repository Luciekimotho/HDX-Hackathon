Controller = require 'controllers/base/controller'
MainView = require 'views/main-view'
config= require 'config'
utils = require 'lib/utils'
mediator = require 'mediator'

module.exports = class SiteController extends Controller
  initialize: (params) =>
    utils.log "initialize site-controller"
    @title = config.site.title

  getOptions: =>
    f = (model) -> parseFloat(model.get 'bednet') / 100
    console.log @collection
    data = for model in @collection.models
      _.extend model.toJSON(), {bednet: f model}

    console.log 'data', data

    options =
      collection: @collection
      topology: @topology.get 'topology'
      names: @names.toJSON()
      data: data

  show: (params) =>
    utils.log "home site-controller"
    @url = utils.reverse 'site#show', params

    if mediator.synced.food
      @viewPage @getOptions()
    else
      @subscribeEvent 'synced:food', -> @viewPage @getOptions()

  viewPage: (options) =>
    @adjustTitle @title
    mediator.setUrl @url
    utils.log @title, 'pageview'
    @view = new MainView options
