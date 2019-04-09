# frozen_string_literal: false

ArJdbc.load_java_part :MSSQL

require 'strscan'

require 'arel'
require 'arel/visitors/bind_visitor'
require 'arel/visitors/sqlserver'
require 'active_record/connection_adapters/abstract_adapter'


require 'arjdbc/abstract/core'
require 'arjdbc/abstract/connection_management'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/statement_cache'
require 'arjdbc/abstract/transaction_support'

require 'arjdbc/mssql/column'
require 'arjdbc/mssql/types'
require 'arjdbc/mssql/quoting'
require 'arjdbc/mssql/schema_statements'
require 'arjdbc/mssql/database_statements'
require 'arjdbc/mssql/explain_support'
require 'arjdbc/mssql/extensions'
require 'arjdbc/mssql/errors'

# require 'arjdbc/util/quoted_cache'

module ArJdbc
  module MSSQL
    require 'arjdbc/mssql/utils'
    require 'arjdbc/mssql/limit_helpers'
    require 'arjdbc/mssql/lock_methods'

    include LimitHelpers
    include Utils
  end
end

module ActiveRecord
  module ConnectionAdapters
    # MSSQL (SQLServer) adapter class definition
    class MSSQLAdapter < AbstractAdapter
      ADAPTER_NAME = 'MSSQL'.freeze

      include ArJdbc::Abstract::Core
      include ArJdbc::Abstract::ConnectionManagement
      include ArJdbc::Abstract::DatabaseStatements
      include ArJdbc::Abstract::StatementCache
      include ArJdbc::Abstract::TransactionSupport

      # include ::ArJdbc::MSSQL
      # include ::ArJdbc::Util::QuotedCache

      include MSSQL::Quoting
      include MSSQL::SchemaStatements
      include MSSQL::DatabaseStatements
      include MSSQL::ExplainSupport

      @cs_equality_operator = 'COLLATE Latin1_General_CS_AS_WS'

      class << self
        attr_accessor :cs_equality_operator
      end

      def initialize(connection, logger, _connection_parameters, config = {})
        # configure_connection happens in super
        super(connection, logger, config)
      end

      # Returns the (JDBC) connection class to be used for this adapter.
      # The class is defined in the java part
      def jdbc_connection_class(_spec)
        ::ActiveRecord::ConnectionAdapters::MSSQLJdbcConnection
      end

      # Returns the (JDBC) `ActiveRecord` column class for this adapter.
      # Used in the java part.
      def jdbc_column_class
        ::ActiveRecord::ConnectionAdapters::MSSQLColumn
      end

      # Can this adapter determine the primary key for tables not attached
      # to an Active Record class, such as join tables?
      def supports_primary_key?
        true
      end

      # Does this adapter support creating foreign key constraints?
      def supports_foreign_keys?
        false
      end

      # Does this adapter support migrations?
      def supports_migrations?
        true
      end

      # Does this adapter support setting the isolation level for a transaction?
      def supports_transaction_isolation?
        true
      end

      # Overrides abstract method which always returns false
      def valid_type?(type)
        !native_database_types[type].nil?
      end

      # FIXME: to be reviewed.
      def clear_cache!
        reload_type_map
        super
      end

      # Overrides the method in abstract adapter to set the limit and offset
      # in the right order. (SQLServer specific)
      # Called by bound_attributes
      def combine_bind_parameters(
        from_clause: [],
        join_clause: [],
        where_clause: [],
        having_clause: [],
        limit: nil,
        offset: nil
      )

        result = from_clause + join_clause + where_clause + having_clause
        result << offset if offset
        result << limit if limit
        result
      end

      def arel_visitor # :nodoc:
        ::Arel::Visitors::SQLServer.new(self)
      end

      # Returns the name of the current security context
      def current_user
        @current_user ||= select_value('SELECT CURRENT_USER')
      end

      # Returns the default schema (to be used for table resolution)
      # used for the {#current_user}.
      def default_schema
        @default_schema ||= select_value('SELECT default_schema_name FROM sys.database_principals WHERE name = CURRENT_USER')
      end

      alias_method :current_schema, :default_schema

      # Allows for changing of the default schema.
      # (to be used during unqualified table name resolution).
      def default_schema=(default_schema)
        execute("ALTER #{current_user} WITH DEFAULT_SCHEMA=#{default_schema}")
        @default_schema = nil if defined?(@default_schema)
      end

      alias_method :current_schema=, :default_schema=

      # Overrides method in abstract adapter
      def case_sensitive_comparison(table, attribute, column, value)
        if value.nil?
          table[attribute].eq(value)
        elsif value.acts_like?(:string)
          table[attribute].eq(Arel::Nodes::Bin.new(Arel::Nodes::BindParam.new))
        else
          table[attribute].eq(Arel::Nodes::BindParam.new)
        end
      end

      def configure_connection
        execute("SET LOCK_TIMEOUT #{lock_timeout}")
      end

      def lock_timeout
        timeout = config[:lock_timeout].to_i

        if timeout.positive?
          timeout
        else
          5_000
        end
      end

      protected

      def translate_exception(e, message)
        case message
        when /(cannot insert duplicate key .* with unique index) | (violation of unique key constraint)/i
          RecordNotUnique.new(message)
        when /Lock request time out period exceeded/i
          LockTimeout.new(message)
        # when /(String or binary data would be truncated)/i
        #   ValueTooLong.new(message)
        else
          super
        end
      end

      # This method is called indirectly by the abstract method
      # 'fetch_type_metadata' which then it is called by the java part when
      # calculating a table's columns.
      def initialize_type_map(map)
        # Build the type mapping from SQL Server to ActiveRecord

        # Integer types.
        map.register_type 'int',      MSSQL::Type::Integer.new(limit: 4)
        map.register_type 'tinyint',  MSSQL::Type::TinyInteger.new(limit: 1)
        map.register_type 'smallint', MSSQL::Type::SmallInteger.new(limit: 2)
        map.register_type 'bigint',   MSSQL::Type::BigInteger.new(limit: 8)

        # Exact Numeric types.
        map.register_type %r{\Adecimal}i do |sql_type|
          scale = extract_scale(sql_type)
          precision = extract_precision(sql_type)
          if scale == 0
            MSSQL::Type::DecimalWithoutScale.new(precision: precision)
          else
            MSSQL::Type::Decimal.new(precision: precision, scale: scale)
          end
        end
        map.register_type %r{\Amoney\z}i,      MSSQL::Type::Money.new
        map.register_type %r{\Asmallmoney\z}i, MSSQL::Type::SmallMoney.new

        # Approximate Numeric types.
        map.register_type %r{\Afloat\z}i,    MSSQL::Type::Float.new
        map.register_type %r{\Areal\z}i,     MSSQL::Type::Real.new

        # Character strings CHAR and VARCHAR (it can become Unicode UTF-8)
        map.register_type 'varchar(max)', MSSQL::Type::VarcharMax.new
        map.register_type %r{\Avarchar\(\d+\)} do |sql_type|
          limit = extract_limit(sql_type)
          MSSQL::Type::Varchar.new(limit: limit)
        end
        map.register_type %r{\Achar\(\d+\)} do |sql_type|
          limit = extract_limit(sql_type)
          MSSQL::Type::Char.new(limit: limit)
        end

        # Character strings NCHAR and NVARCHAR (by default Unicode UTF-16)
        map.register_type %r{\Anvarchar\(\d+\)} do |sql_type|
          limit = extract_limit(sql_type)
          MSSQL::Type::Nvarchar.new(limit: limit)
        end
        map.register_type %r{\Anchar\(\d+\)} do |sql_type|
          limit = extract_limit(sql_type)
          MSSQL::Type::Nchar.new(limit: limit)
        end
        map.register_type 'nvarchar(max)', MSSQL::Type::NvarcharMax.new
        map.register_type 'nvarchar(4000)', MSSQL::Type::Nvarchar.new

        # Binary data types.
        map.register_type              'varbinary(max)',       MSSQL::Type::VarbinaryMax.new
        register_class_with_limit map, %r{\Abinary\(\d+\)},    MSSQL::Type::BinaryBasic
        register_class_with_limit map, %r{\Avarbinary\(\d+\)}, MSSQL::Type::Varbinary

        # Miscellaneous types, Boolean, XML, UUID
        # FIXME The xml data needs to be reviewed and fixed
        map.register_type 'bit',                     MSSQL::Type::Boolean.new
        map.register_type %r{\Auniqueidentifier\z}i, MSSQL::Type::UUID.new
        map.register_type %r{\Axml\z}i,              MSSQL::Type::XML.new

        # Date and time types
        map.register_type 'date',          MSSQL::Type::Date.new
        map.register_type 'datetime',      MSSQL::Type::DateTime.new
        map.register_type 'smalldatetime', MSSQL::Type::SmallDateTime.new
        register_class_with_precision map, %r{\Atime\(\d+\)}i, MSSQL::Type::Time
        map.register_type 'time(7)',       MSSQL::Type::Time.new

        # aliases
        map.alias_type 'int identity',    'int'
        map.alias_type 'bigint identity', 'bigint'
        map.alias_type 'integer',         'int'
        map.alias_type 'integer',         'int'
        map.alias_type 'INTEGER',         'int'
        map.alias_type 'TINYINT',         'tinyint'
        map.alias_type 'SMALLINT',        'smallint'
        map.alias_type 'BIGINT',          'bigint'
        map.alias_type %r{\Anumeric}i,    'decimal'
        map.alias_type %r{\Anumber}i,     'decimal'
        map.alias_type %r{\Adouble\z}i,   'float'
        map.alias_type 'string',          'nvarchar(4000)'
        map.alias_type %r{\Aboolean\z}i,  'bit'
        map.alias_type 'DATE',            'date'
        map.alias_type 'DATETIME',        'datetime'
        map.alias_type 'SMALLDATETIME',   'smalldatetime'
        map.alias_type %r{\Atime\z}i,     'time(7)'
        map.alias_type %r{\Abinary\z}i,   'varbinary(max)'
        map.alias_type %r{\Ablob\z}i,     'varbinary(max)'



        # Deprecated SQL Server types.
        map.register_type 'text',  MSSQL::Type::Text.new
        map.register_type 'ntext', MSSQL::Type::Ntext.new
        map.register_type 'image', MSSQL::Type::Image.new
      end
    end
  end
end
