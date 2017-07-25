module ArJdbc
  # This is minimum amount of code neede from base JDBC Adapter class to make common adapters
  # work.  This replaces using jdbc/adapter as a base class for all adapters.
  module CommonJdbcMethods
    def initialize(connection, logger = nil, config = {})
      config[:adapter_spec] = adapter_spec(config) unless config.key?(:adapter_spec)

      connection ||= jdbc_connection_class(config[:adapter_spec]).new(config, self)

      super(connection, logger, config)
    end
  end
end
