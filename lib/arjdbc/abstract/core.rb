module ArJdbc
  module Abstract

    # This is minimum amount of code needed from base JDBC Adapter class to make common adapters
    # work.  This replaces using jdbc/adapter as a base class for all adapters.
    module Core

      attr_reader :config

      def initialize(connection, logger = nil, config = {})
        @config = config

        if self.class.equal? ActiveRecord::ConnectionAdapters::JdbcAdapter
          spec = @config.key?(:adapter_spec) ? @config[:adapter_spec] :
                     ( @config[:adapter_spec] = adapter_spec(@config) ) # due resolving visitor
          extend spec if spec
        end

        connection ||= jdbc_connection_class(config[:adapter_spec]).new(config, self)

        super(connection, logger, config) # AbstractAdapter

        connection.configure_connection # will call us (maybe)
      end

      # Retrieve the raw `java.sql.Connection` object.
      # The unwrap parameter is useful if an attempt to unwrap a pooled (JNDI)
      # connection should be made - to really return the 'native' JDBC object.
      # @param unwrap [true, false] whether to unwrap the connection object
      # @return [Java::JavaSql::Connection] the JDBC connection
      def jdbc_connection(unwrap = nil)
        raw_connection.jdbc_connection(unwrap)
      end

      protected

      def translate_exception_class(e, sql)
        begin
          message = "#{e.class.name}: #{e.message}: #{sql}"
        rescue Encoding::CompatibilityError
          message = "#{e.class.name}: #{e.message.force_encoding sql.encoding}: #{sql}"
        end

        exception = translate_exception(e, message)
        exception.set_backtrace e.backtrace unless e.equal?(exception)
        exception
      end

      def translate_exception(e, message)
        # we shall not translate native "Java" exceptions as they might
        # swallow an ArJdbc / driver bug into an AR::StatementInvalid !
        return e if e.is_a?(Java::JavaLang::Throwable)

        case e
          when SystemExit, SignalException, NoMemoryError then e
          when ActiveModel::RangeError, TypeError, RuntimeError then e
          else super
        end
      end

      def extract_raw_bind_values(binds)
        binds.map(&:value_for_database)
      end

      # this version of log() automatically fills type_casted_binds from binds if necessary
      def log(sql, name = "SQL", binds = [], type_casted_binds = [], statement_name = nil)
        if binds.any? && (type_casted_binds.nil? || type_casted_binds.empty?)
          type_casted_binds = ->{ extract_raw_bind_values(binds) }
        end
        super
      end
    end
  end
end
