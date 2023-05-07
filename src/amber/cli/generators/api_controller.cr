module Amber::CLI
  class ApiController < Amber::CLI::Generator
    directory "#{__DIR__}/../templates/api/controller"

    def initialize(name, fields)
      super(name, fields)
      add_timestamp_fields
    end

    def pre_render(directory, **args)
      add_routes
    end

    private def add_routes
      add_routes :api, <<-ROUTE
        json_api "/api/v1/#{name_plural}", #{class_name}Controller
      ROUTE
    end
  end
end
