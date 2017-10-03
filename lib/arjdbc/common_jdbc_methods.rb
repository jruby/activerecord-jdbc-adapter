module ArJdbc
  # This is minimum amount of code neede from base JDBC Adapter class to make common adapters
  # work.  This replaces using jdbc/adapter as a base class for all adapters.
  module CommonJdbcMethods
    def initialize(connection, logger = nil, config = {})
      config[:adapter_spec] = adapter_spec(config) unless config.key?(:adapter_spec)

      connection ||= jdbc_connection_class(config[:adapter_spec]).new(config, self)

      super(connection, logger, config)
    end

    def translate_exception(e, message)
      # we shall not translate native "Java" exceptions as they might
      # swallow an ArJdbc / driver bug into a AR::StatementInvalid ...
      return e if e.is_a?(NativeException) # JRuby 1.6
      return e if e.is_a?(Java::JavaLang::Throwable)

      case e
        when ActiveModel::RangeError, SystemExit, SignalException, NoMemoryError then e
        # NOTE: wraps AR::JDBCError into AR::StatementInvalid, desired ?!
        else super
      end
    end

  end
end
