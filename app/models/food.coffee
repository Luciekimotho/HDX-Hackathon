Collection = require 'models/base/collection'
Model = require 'models/base/model'
utils = require 'lib/utils'
devconfig = require 'devconfig'

module.exports = class Food extends Collection
  model: Model
  type: 'food'
  file: devconfig.storage.file
  local: devconfig.storage.local
  remote: devconfig.storage.remote

  initialize: (options) =>
    super
    @url = "data/#{@type}"

  parse: (resp) =>
    utils.log "parsing #{@type} resp"
    resp
