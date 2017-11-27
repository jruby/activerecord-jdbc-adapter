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
  class ConnectionAdapters::AbstractMysqlAdapter
    # FIXME: this is to work around abstract mysql having 4 arity but core wants to pass 3
    # FIXME: Missing the logic from original module.
    def initialize(connection, logger, config)
      super(connection, logger, config)
    end
  end
  module ConnectionAdapters
    # Remove any vestiges of core/Ruby MySQL adapter
    remove_const(:Mysql2Adapter) if const_defined?(:Mysql2Adapter)

    class Mysql2Adapter < AbstractMysqlAdapter
      ADAPTER_NAME = 'Mysql2'.freeze

      include ArJdbc::Abstract::Core
      include ArJdbc::Abstract::ConnectionManagement
      include ArJdbc::Abstract::DatabaseStatements
      include ArJdbc::Abstract::StatementCache
      include ArJdbc::Abstract::TransactionSupport

      def initialize(connection, logger, connection_options, config)
        super(connection, logger, config)

        @prepared_statements = false unless config.key?(:prepared_statements)

        configure_connection
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

      def supports_transaction_isolation?
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
        exception.errno if exception.respond_to? :errno
      end

      def create_table(table_name, **options) #:nodoc:
        super(table_name, options: "ENGINE=InnoDB", **options)
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

      def quote_string(string)
        string.gsub(/[\x00\n\r\\\'\"]/, '\\\\\0')
      end

      def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
        last_id = if without_prepared_statement?(binds)
                    log(sql, name) { @connection.execute_insert(sql) }
                  else
                    log(sql, name, binds) { @connection.execute_insert(sql, binds) }
                  end
        # FIXME: execute_insert and executeUpdate mapping key results is very varied and I am wondering
        # if AR is now much more consistent.  I worked around by manually making a result here.
        ::ActiveRecord::Result.new(nil, [[last_id]])
      end
      alias insert_sql exec_insert
      deprecate insert_sql: :insert

      private

      def full_version
        @full_version ||= begin
          result = execute 'SELECT VERSION()', 'SCHEMA'
          result.first.values.first # [{"VERSION()"=>"5.5.37-0ubuntu..."}]
        end
      end

      def jdbc_connection_class(spec)
        ::ActiveRecord::ConnectionAdapters::MySQLJdbcConnection
      end

      def jdbc_column_class
        ::ActiveRecord::ConnectionAdapters::MySQL::Column
      end

    end
  end

  # FIXME: #834 Not sure how this is scoped or whether we should use it or just alias it to our
  # JDBCError.
  class ::Mysql2
    class Error < Exception
      def initialize(*)
        super("error")
      end
    end
  end
end
