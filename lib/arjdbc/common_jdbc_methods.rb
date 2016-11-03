module ArJdbc
  # This is minimum amount of code neede from base JDBC Adapter class to make common adapters
  # work.  This replaces using jdbc/adapter as a base class for all adapters.
  module CommonJdbcMethods
    def initialize(connection, logger = nil, config = {})
      config[:adapter_spec] = adapter_spec(config) unless config.key?(:adapter_spec)

      connection ||= jdbc_connection_class(config[:adapter_spec]).new(config, self)

      super(connection, logger, config)
    end

    def execute(sql, name = nil)
      # FIXME: Can we kill :skip_logging?
      if name == :skip_logging
        @connection.execute(sql)
      else
        log(sql, name) { @connection.execute(sql) }
      end
    end

    # Take an id from the result of an INSERT query.
    # @return [Integer, NilClass]
    def last_inserted_id(result)
      if result.is_a?(Hash) || result.is_a?(ActiveRecord::Result)
        result.first.first[1] # .first = { "id"=>1 } .first = [ "id", 1 ]
      else
        result
      end
    end
  end
end