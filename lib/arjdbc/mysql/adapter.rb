ArJdbc.load_java_part :MySQL

require 'bigdecimal'
require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/abstract/schema_definitions'
require 'arjdbc/abstract/core'
require 'arjdbc/abstract/connection_management'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/statement_cache'
require 'arjdbc/abstract/transaction_support'

module ActiveRecord
  module ConnectionAdapters
    AbstractMysqlAdapter.class_eval do
      include ArJdbc::Abstract::Core # to have correct initialize() super
    end

    # Remove any vestiges of core/Ruby MySQL adapter
    remove_const(:Mysql2Adapter) if const_defined?(:Mysql2Adapter)

    class Mysql2Adapter < AbstractMysqlAdapter
      ADAPTER_NAME = 'Mysql2'.freeze

      include Jdbc::ConnectionPoolCallbacks

      include ArJdbc::Abstract::ConnectionManagement
      include ArJdbc::Abstract::DatabaseStatements
      # NOTE: do not include MySQL::DatabaseStatements
      include ArJdbc::Abstract::StatementCache
      include ArJdbc::Abstract::TransactionSupport

      include ArJdbc::MySQL

      def initialize(connection, logger, config)
        super(connection, logger, nil, config)
        @prepared_statements = false unless config.key?(:prepared_statements)
        # configure_connection taken care of at ArJdbc::Abstract::Core
      end

      def supports_json?
        !mariadb? && version >= '5.7.8'
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

      # HELPER METHODS ===========================================

      # Reloading the type map in abstract/statement_cache.rb blows up postgres
      def clear_cache!
        reload_type_map
        super
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

      def create_table(table_name, **options) #:nodoc:
        super(table_name, options: "ENGINE=InnoDB", **options)
      end

      #--
      # QUOTING ==================================================
      #++

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

      alias :reset! :reconnect!

      #

      private

      # e.g. "5.7.20-0ubuntu0.16.04.1"
      def full_version; @full_version ||= @connection.full_version end

      def jdbc_connection_class(spec)
        ::ActiveRecord::ConnectionAdapters::MySQLJdbcConnection
      end

      def jdbc_column_class
        ::ActiveRecord::ConnectionAdapters::MySQL::Column
      end

    end
  end
end
