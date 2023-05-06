module Amber::Controller::Helpers
  module ApiQuery
    DEFAULT_LIMIT = 100

    alias RawFilter = NamedTuple(name: String, op: String, value: Bool | Float64 | Int32 | Int64 | String | Array(String))
    alias ParamFilter = NamedTuple(name: String, op: Symbol, value: Bool | Float64 | Int32 | Int64 | String | Array(String))

    def limit_offset_args
      limit = params[:limit]?.nil? ? DEFAULT_LIMIT : params[:limit].to_i
      offset = params[:offset]?.nil? ? 0 : params[:offset].to_i
      {limit, offset}
    end

    def order_by_args : Hash(String, Symbol)
      order_by = params["order_by"]?.nil? ? Array(String).new : params["order_by"].split(",")
      order_by.to_h do |item|
        parts = item.split(":")
        {parts.first, parts.last == "desc" ? :desc : :asc}
      end.reject! { |k, _| k.empty? }
    end

    private def string_to_operator(str)
      {% begin %}
      case str
      {% for op in [:eq, :gteq, :lteq, :neq, :gt, :lt, :nlt, :ngt, :ltgt, :in, :nin, :like, :nlike] %}
      when "{{op.id}}", "{{op}}", {{op}}
        {{op}}
      {% end %}
      else
        raise "unknown filter operator #{str}"
      end
      {% end %}
    end

    def param_args : Array(ParamFilter)
      filters = Array(ParamFilter).new
      _filters = params["filter[]"]?
      return filters if _filters.nil?

      (_filters.is_a?(String) ? [_filters] : _filters).map do |item|
        begin
          filter = RawFilter.from_json(item)
          filters << {
            name:  filter[:name],
            op:    string_to_operator(filter[:op]),
            value: filter[:value],
          }
        rescue ex : JSON::ParseException
          raise "invalid filter"
        rescue ex
          Log.error(exception: ex) { ex.message }
          raise ex
        end
      end

      filters
    end
  end
end
