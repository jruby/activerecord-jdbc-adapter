# frozen_string_literal: true

ArJdbc.load_java_part :MySQL

require 'bigdecimal'
require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/abstract/schema_definitions'
require 'arjdbc/abstract/core'
require 'arjdbc/abstract/connection_management'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/statement_cache'
require 'arjdbc/abstract/transaction_support'

require "arjdbc/mysql/adapter_hash_config"

require "arjdbc/abstract/relation_query_attribute_monkey_patch"

module ActiveRecord
  module ConnectionAdapters
    AbstractMysqlAdapter.class_eval do
      include ArJdbc::Abstract::Core # to have correct initialize() super
    end

    # Remove any vestiges of core/Ruby MySQL adapter
    remove_const(:Mysql2Adapter) if const_defined?(:Mysql2Adapter)

    class Mysql2Adapter < AbstractMysqlAdapter
      ADAPTER_NAME = 'Mysql2'

      # include Jdbc::ConnectionPoolCallbacks

      include ArJdbc::Abstract::ConnectionManagement
      include ArJdbc::Abstract::DatabaseStatements
      # NOTE: do not include MySQL::DatabaseStatements
      include ArJdbc::Abstract::StatementCache
      include ArJdbc::Abstract::TransactionSupport

      include ArJdbc::MySQL
      include ArJdbc::MysqlConfig

      class << self
        def jdbc_connection_class
          ::ActiveRecord::ConnectionAdapters::MySQLJdbcConnection
        end

        def new_client(conn_params, adapter_instance)
          jdbc_connection_class.new(conn_params, adapter_instance)
        end

        private
          def initialize_type_map(m)
            super

            m.register_type(%r(char)i) do |sql_type|
              limit = extract_limit(sql_type)
              Type.lookup(:string, adapter: :mysql2, limit: limit)
            end

            m.register_type %r(^enum)i, Type.lookup(:string, adapter: :mysql2)
            m.register_type %r(^set)i,  Type.lookup(:string, adapter: :mysql2)
          end
      end

      # NOTE: redefines constant defined in abstract class however this time
      # will use methods defined in the mysql abstract class and map properly
      # mysql types.
      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) }

      def initialize(...)
        super

        @config[:flags] ||= 0

        # assign arjdbc extra connection params
        conn_params = build_connection_config(@config.compact)

        # JDBC mysql appears to use found rows by default: https://dev.mysql.com/doc/connector-j/en/connector-j-connp-props-connection.html
        # if @config[:flags].kind_of? Array
        #   @config[:flags].push "FOUND_ROWS"
        # else
        #   @config[:flags] |= ::Mysql2::Client::FOUND_ROWS
        # end

        @connection_parameters = conn_params
      end

      def supports_json?
        !mariadb? && database_version >= '5.7.8'
      end

      def supports_comments?
        true
      end

      def supports_comments_in_create?
        true
      end

      def supports_savepoints?
        true
      end

      def supports_lazy_transactions?
        true
      end

      def supports_transaction_isolation?
        true
      end

      def supports_set_server_option?
        false
      end

      # HELPER METHODS ===========================================

      # from MySQL::DatabaseStatements
      READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
        :desc, :describe, :set, :show, :use
      ) # :nodoc:
      private_constant :READ_QUERY

      def write_query?(sql) # :nodoc:
        !READ_QUERY.match?(sql)
      end

      def explain(arel, binds = [], options = [])
        sql     = build_explain_clause(options) + " " + to_sql(arel, binds)
        start   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result  = internal_exec_query(sql, "EXPLAIN", binds)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

        MySQL::ExplainPrettyPrinter.new.pp(result, elapsed)
      end

      def build_explain_clause(options = [])
        return "EXPLAIN" if options.empty?

        explain_clause = "EXPLAIN #{options.join(" ").upcase}"
        
        if analyze_without_explain? && explain_clause.include?("ANALYZE")
          explain_clause.sub("EXPLAIN ", "")
        else
          explain_clause
        end
      end

      def each_hash(result) # :nodoc:
        if block_given?
          # FIXME: This is C in mysql2 gem and I just made simplest Ruby
          result.each do |row|
            new_hash = {}
            row.each { |k, v| new_hash[k.to_sym] = v }
            yield new_hash
          end
        else
          to_enum(:each_hash, result)
        end
      end

      def error_number(exception)
        exception.error_code if exception.is_a?(JDBCError)
      end

      #--
      # QUOTING ==================================================
      #+

      # FIXME: 5.1 crashes without this.  I think this is Arel hitting a fallback path in to_sql.rb.
      # So maybe an untested code path in their source.  Still means we are doing something wrong to
      # even hit it.
      def quote(value, comment=nil)
        super(value)
      end

      # NOTE: quote_string(string) provided by ArJdbc::MySQL (native code),
      # this piece is also native (mysql2) under MRI: `@connection.escape(string)`

      def quoted_date(value)
        if supports_datetime_with_precision?
          super
        else
          super.sub(/\.\d{6}\z/, '')
        end
      end

      def _quote(value)
        if value.is_a?(Type::Binary::Data)
          "x'#{value.hex}'"
        else
          super
        end
      end
      private :_quote

      #--
      # CONNECTION MANAGEMENT ====================================
      #++

      def active?
        !(@raw_connection.nil? || @raw_connection.closed?) && @lock.synchronize { @raw_connection&.ping } || false
      end

      alias :reset! :reconnect!

      # Commits the current database transaction.
      #
      # Overrides ArJdbc::Abstract::TransactionSupport to disable connection
      # retries for COMMIT, matching ActiveRecord's native MySQL adapter
      # (which uses `allow_retry: false`). Retrying a COMMIT after a connection
      # failure is unsafe on a networked database: `with_raw_connection` would
      # reconnect, replay an *empty* transaction (the original writes died with
      # the dropped backend), COMMIT it successfully, and report success -
      # silently losing the transaction's writes.
      def commit_db_transaction
        log('COMMIT', 'TRANSACTION') do
          with_raw_connection(allow_retry: false, materialize_transactions: true) do |conn|
            conn.commit
          end
        end
      end

      # Rolls back the current database transaction.
      #
      # Overrides ArJdbc::Abstract::TransactionSupport to match ActiveRecord's
      # native MySQL adapter (`allow_retry: false`).
      def exec_rollback_db_transaction
        log('ROLLBACK', 'TRANSACTION') do
          with_raw_connection(allow_retry: false, materialize_transactions: true) do |conn|
            conn.rollback
          end
        end
      end

      # Disconnects from the database if already connected.
      # Otherwise, this method does nothing.
      def disconnect!
        @lock.synchronize do
          super
          @raw_connection&.close
          @raw_connection = nil
        end
      end

      def discard! # :nodoc:
        @lock.synchronize do
          super
          @raw_connection&.automatic_close = false
          @raw_connection = nil
        end
      end

      #

      private
      # https://mariadb.com/kb/en/analyze-statement/
      def analyze_without_explain?
        mariadb? && database_version >= "10.1.0"
      end

      def text_type?(type)
        TYPE_MAP.lookup(type).is_a?(Type::String) || TYPE_MAP.lookup(type).is_a?(Type::Text)
      end

      def configure_connection
        # @raw_connection.query_options[:as] = :array
        # @raw_connection.query_options[:database_timezone] = default_timezone
        super
      end

      # e.g. "5.7.20-0ubuntu0.16.04.1"
      def full_version
        database_version.full_version_string
      end

      def get_full_version
        @full_version ||= any_raw_connection.full_version
      end

      def jdbc_column_class
        ::ActiveRecord::ConnectionAdapters::MySQL::Column
      end

      # MySQL / MariaDB surface a dropped server connection as a JDBC error in
      # SQLState class 08 (connection exception) - most commonly 08S01
      # "Communications link failure" - or with one of the "server gone" vendor
      # error codes. The driver may also wrap it in a recoverable / non-transient
      # connection exception. None of these are caught by the message- and
      # error-code-based cases below (which fall through to a plain JDBCError /
      # StatementInvalid), so AR's with_raw_connection reconnect/retry machinery
      # never kicks in. See https://dev.mysql.com/doc/connector-j/en/connector-j-reference-error-sqlstates.html
      CONNECTION_FAILURE_SQL_STATES = %w[
        08000
        08001
        08003
        08004
        08006
        08007
        08S01
      ].freeze
      # CR_SERVER_GONE_ERROR (2006), CR_SERVER_LOST (2013),
      # ER_SERVER_SHUTDOWN (1053), ER_CONNECTION_KILLED (1927),
      # ER_CLIENT_INTERACTION_TIMEOUT (4031).
      CONNECTION_FAILURE_ERROR_CODES = [2006, 2013, 1053, 1927, 4031].freeze
      CONNECTION_FAILURE_MESSAGES = /
        Communications?\ link\ failure |
        No\ operations\ allowed\ after\ connection\ closed |
        Connection\.*\ refused |
        Could\ not\ connect\ to |
        Server\ shutdown\ in\ progress |
        Connection\ is\ closed
      /x.freeze
      private_constant :CONNECTION_FAILURE_SQL_STATES, :CONNECTION_FAILURE_ERROR_CODES, :CONNECTION_FAILURE_MESSAGES

      def translate_exception(exception, message:, sql:, binds:)
        if exception.is_a?(::ActiveRecord::JDBCError) && connection_lost?(exception)
          return ::ActiveRecord::ConnectionFailed.new(message, sql: sql, binds: binds, connection_pool: @pool)
        end

        case message
        when /Table .* doesn't exist/i
          StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
        when /BLOB, TEXT, GEOMETRY or JSON column .* can't have a default value/i
          StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
        else
          super
        end
      end

      # Detects a lost server connection from a JDBC error so it can be
      # translated to ActiveRecord::ConnectionFailed (retryable). Mirrors the
      # PostgreSQL adapter's handling of backend disconnects (e.g. a proxy such
      # as ProxySQL dropping an idle connection).
      def connection_lost?(exception)
        state = exception.sql_state if exception.respond_to?(:sql_state)
        return true if state && CONNECTION_FAILURE_SQL_STATES.include?(state)

        code = exception.error_code if exception.respond_to?(:error_code)
        return true if code && CONNECTION_FAILURE_ERROR_CODES.include?(code)

        message = exception.message
        return true if message && CONNECTION_FAILURE_MESSAGES.match?(message)

        cause = exception.cause if exception.respond_to?(:cause)
        cause.is_a?(Java::JavaSql::SQLRecoverableException) ||
          cause.is_a?(Java::JavaSql::SQLNonTransientConnectionException)
      end

      # defined in MySQL::DatabaseStatements which is not included
      def default_insert_value(column)
        super unless column.auto_increment?
      end

      # FIXME: optimize insert_fixtures_set by using JDBC Statement.addBatch()/executeBatch()

      def combine_multi_statements(total_sql)
        if total_sql.length == 1
          total_sql.first
        else
          total_sql
        end
      end
    end
  end
end
