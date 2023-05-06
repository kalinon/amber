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

    def param_args(filter_params : Array(Open::Api::Parameter)) : Array(ParamFilter)
      filters = Array(ParamFilter).new
      filter_params.each do |param|
        val = param_filter(param)
        unless val.nil?
          filters << val
        end
      end

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

    # Convert the `Open::Api::Parameter` to a filter struct
    private def param_filter(param : Open::Api::Parameter) : ParamFilter?
      param_name = param.name
      op = :eq
      param_value = param_value(param)
      return nil if param_value.nil?

      if param_name =~ /^(.*)_(:\w+)$/
        param_name = $1
        op = string_to_operator($2)
      end

      case param_value
      when String
        if op == :in || op == :nin
          param_value = param_value.split(',')
        elsif op == :like || op == :nlike
          param_value = "%#{param_value}%"
        end
        {name: param_name, op: op, value: param_value}
      when Bool, Float64, Int64
        {name: param_name, op: op, value: param_value}
      else
        nil
      end
    end

    # Fetch the value from the http request
    def param_value(param : Open::Api::Parameter)
      case param.parameter_in
      when "query", "path", "body"
        params[param.name]?.nil? ? nil : params[param.name]
      when "header"
        request.headers[param.name]?.nil? ? nil : request.headers[param.name]
      else
        nil
      end
    end
  end
end
