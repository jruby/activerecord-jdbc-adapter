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

      # Does this adapter support migrations?
      def supports_migrations?
        true
      end

      # Does this adapter support setting the isolation level for a transaction?
      def supports_transaction_isolation?(level = nil)
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

      alias current_schema default_schema

      # Allows for changing of the default schema.
      # (to be used during unqualified table name resolution).
      def default_schema=(default_schema)
        execute("ALTER #{current_user} WITH DEFAULT_SCHEMA=#{default_schema}")
        @default_schema = nil if defined?(@default_schema)
      end

      alias current_schema= default_schema=

      private

      # This method is called indirectly by the abstract method
      # 'fetch_type_metadata' which then it is called by the java part when
      # calculating a table's columns.
      def initialize_type_map(map)
        # Build the type mapping from SQL Server to ActiveRecord
        # Integer types.
        map.register_type 'int(4)',          MSSQL::Type::Integer.new(limit: 4)
        map.register_type 'int identity(4)', MSSQL::Type::Integer.new(limit: 4)
        map.register_type 'tinyint(1)',      MSSQL::Type::TinyInteger.new(limit: 1)
        map.register_type 'smallint(2)',     MSSQL::Type::SmallInteger.new(limit: 2)
        map.register_type 'bigint(8)',       MSSQL::Type::BigInteger.new(limit: 8)
        # Boolean type.
        map.register_type 'bit',             MSSQL::Type::Boolean.new
        # Exact Numeric types.
        map.register_type %r{\Adecimal} do |sql_type|
          scale = extract_scale(sql_type)
          precision = extract_precision(sql_type)
          MSSQL::Type::Decimal.new(precision: precision, scale: scale)
        end
        map.register_type 'money',      MSSQL::Type::Money.new
        map.register_type 'smallmoney', MSSQL::Type::SmallMoney.new
        # Approximate Numeric types.
        map.register_type %r{\Afloat},      ActiveRecord::Type::Float.new
        map.register_type %r{\Areal},       RealType.new

        # aliases
        map.alias_type 'int',             'int(4)'
        map.alias_type 'int identity',    'int(4)'
        map.alias_type 'integer',         'int(4)'
        map.alias_type 'tinyint',         'tinyint(1)'
        map.alias_type 'smallint',        'smallint(2)'
        map.alias_type 'bigint',          'bigint(8)'
        map.alias_type %r{\Anumeric},     'decimal'


        # map.register_type              %r{.*},             UnicodeStringType.new
        # Date and Time
        map.register_type              /^date\(?/,          ActiveRecord::Type::Date.new
        map.register_type              /^datetime\(?/,      DateTimeType.new
        map.register_type              /smalldatetime/,     SmallDateTimeType.new
        map.register_type              %r{\Atime} do |sql_type|
          TimeType.new :precision => extract_precision(sql_type)
        end
        # Character Strings
        register_class_with_limit map, %r{\Achar}i,         CharType
        # register_class_with_limit map, %r{\Avarchar}i,      VarcharType
        map.register_type              %r{\Anvarchar}i do |sql_type|
          limit = extract_limit(sql_type)
          if limit == 2_147_483_647 # varchar(max)
            VarcharMaxType.new
          else
            VarcharType.new :limit => limit
          end
        end
        # map.register_type              'varchar(max)',      VarcharMaxType.new
        map.register_type              /^text/,             TextType.new
        # Unicode Character Strings
        register_class_with_limit map, %r{\Anchar}i,        UnicodeCharType
        # register_class_with_limit map, %r{\Anvarchar}i,     UnicodeVarcharType
        map.register_type              %r{\Anvarchar}i do |sql_type|
          limit = extract_limit(sql_type)
          if limit == 1_073_741_823 # nvarchar(max)
            UnicodeVarcharMaxType.new
          else
            UnicodeVarcharType.new :limit => limit
          end
        end
        # map.register_type              'nvarchar(max)',     UnicodeVarcharMaxType.new
        map.alias_type                 'string',            'nvarchar(4000)'
        map.register_type              /^ntext/,            UnicodeTextType.new
        # Binary Strings
        register_class_with_limit map, %r{\Aimage}i,        ImageType
        register_class_with_limit map, %r{\Abinary}i,       BinaryType
        register_class_with_limit map, %r{\Avarbinary}i,    VarbinaryType
        # map.register_type              'varbinary(max)',    VarbinaryMaxType.new
        # Other Data Types
        map.register_type              'uniqueidentifier',  UUIDType.new
        # TODO
        # map.register_type              'timestamp',         SQLServer::Type::Timestamp.new
        map.register_type              'xml',               XmlType.new
      end
    end
  end
end
