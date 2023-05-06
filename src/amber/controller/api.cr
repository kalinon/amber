require "./base"
require "./helpers/api_query"
require "./helpers/model_def"

module Amber::Controller
  class Api(T) < Base
    RESPONSE_TYPE = "application/json"
    include Amber::Controller::Helpers::ApiQuery

    struct ListResp(X)
      include JSON::Serializable

      property limit : Int32
      property offset : Int32
      property size : Int32
      property total : Int32
      property items : Array(X)
    end

    macro inherited
      class_getter model_def : Amber::Controller::Helpers::ModelDef(T) = Amber::Controller::Helpers::ModelDef(T).new
    end

    def model_def : Amber::Controller::Helpers::ModelDef(T)
      self.class.model_def
    end

    def initialize(@context : HTTP::Server::Context)
      super(@context)
      @context.response.content_type = RESPONSE_TYPE
    end

    macro query_list(model)
      limit, offset = limit_offset_args
      order_by = order_by_args
      filters = param_args

      Log.debug &.emit "get {{model.id}}", filters: filters.to_json, limit: limit, offset: offset, order_by: order_by.to_json

      query = {{model.id}}.where
      # If sort is not specified, sort by provided column
      query.order(order_by) unless order_by.empty?

      # If filters are specified, apply them
      model_def.apply_filters.call(filters, query)

      total = query.size.run
      query.offset(offset) if offset > 0
      query.limit(limit) if limit > 0
      items = query.select
      { limit: limit, offset: offset, size: items.size, total: total, items: items }
    end
  end
end
