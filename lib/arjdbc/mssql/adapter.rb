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
    require 'arjdbc/mssql/column'

    include LimitHelpers
    include Utils
  end
end

module ActiveRecord::ConnectionAdapters
  class MSSQLColumn < Column
    # including in MSSQL::Column just the methods
    # that I need as Im fixing the tests to 
    # hopefully see what we really need.
    # have left pre Rails 5 code in old_column.rb
    include ::ArJdbc::MSSQL::Column
  end

  class MSSQLAdapter < AbstractAdapter
    ADAPTER_NAME = 'MSSQL'.freeze

    include ArJdbc::Abstract::Core
    include ArJdbc::Abstract::ConnectionManagement
    include ArJdbc::Abstract::DatabaseStatements
    include ArJdbc::Abstract::StatementCache
    include ArJdbc::Abstract::TransactionSupport

    #include ::ArJdbc::MSSQL
    #include ::ArJdbc::Util::QuotedCache

    include MSSQL::Quoting
    include MSSQL::SchemaStatements
    include MSSQL::DatabaseStatements
    include MSSQL::ExplainSupport

    def initialize(connection, logger = nil, connection_parameters = nil, config = {})
      # configure_connection happens in super
      super(connection, logger, config)
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def jdbc_connection_class(spec)
      ::ActiveRecord::ConnectionAdapters::MSSQLJdbcConnection
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_column_class
    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::MSSQLColumn
    end

    # Does this adapter support migrations?
    def supports_migrations?
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

    private

    # This method is called indirectly by the abstract method
    # 'fetch_type_metadata' which then it is called by the java part.
    def initialize_type_map(m)
      # m.register_type              %r{.*},             UnicodeStringType.new
      # Exact Numerics
      register_class_with_limit m, /^bigint./,          BigIntegerType
      m.alias_type                 'bigint',            'bigint(8)'
      register_class_with_limit m, /^int\(|\s/,         ActiveRecord::Type::Integer
      m.alias_type                 /^integer/,          'int(4)'
      m.alias_type                 'int',               'int(4)'
      register_class_with_limit m, /^smallint./,        SmallIntegerType
      m.alias_type                 'smallint',          'smallint(2)'
      register_class_with_limit m, /^tinyint./,         TinyIntegerType
      m.alias_type                 'tinyint',           'tinyint(1)'
      m.register_type              /^bit/,              ActiveRecord::Type::Boolean.new
      m.register_type              %r{\Adecimal} do |sql_type|
        scale = extract_scale(sql_type)
        precision = extract_precision(sql_type)
        DecimalType.new :precision => precision, :scale => scale
        # if scale == 0
        #   ActiveRecord::Type::Integer.new(:precision => precision)
        # else
        #   DecimalType.new(:precision => precision, :scale => scale)
        # end
      end
      m.alias_type                 %r{\Anumeric},       'decimal'
      m.register_type              /^money/,            MoneyType.new
      m.register_type              /^smallmoney/,       SmallMoneyType.new
      # Approximate Numerics
      m.register_type              /^float/,            ActiveRecord::Type::Float.new
      m.register_type              /^real/,             RealType.new
      # Date and Time
      m.register_type              /^date\(?/,          ActiveRecord::Type::Date.new
      m.register_type              /^datetime\(?/,      DateTimeType.new
      m.register_type              /smalldatetime/,     SmallDateTimeType.new
      m.register_type              %r{\Atime} do |sql_type|
        TimeType.new :precision => extract_precision(sql_type)
      end
      # Character Strings
      register_class_with_limit m, %r{\Achar}i,         CharType
      # register_class_with_limit m, %r{\Avarchar}i,      VarcharType
      m.register_type              %r{\Anvarchar}i do |sql_type|
        limit = extract_limit(sql_type)
        if limit == 2_147_483_647 # varchar(max)
          VarcharMaxType.new
        else
          VarcharType.new :limit => limit
        end
      end
      # m.register_type              'varchar(max)',      VarcharMaxType.new
      m.register_type              /^text/,             TextType.new
      # Unicode Character Strings
      register_class_with_limit m, %r{\Anchar}i,        UnicodeCharType
      # register_class_with_limit m, %r{\Anvarchar}i,     UnicodeVarcharType
      m.register_type              %r{\Anvarchar}i do |sql_type|
        limit = extract_limit(sql_type)
        if limit == 1_073_741_823 # nvarchar(max)
          UnicodeVarcharMaxType.new
        else
          UnicodeVarcharType.new :limit => limit
        end
      end
      # m.register_type              'nvarchar(max)',     UnicodeVarcharMaxType.new
      m.alias_type                 'string',            'nvarchar(4000)'
      m.register_type              /^ntext/,            UnicodeTextType.new
      # Binary Strings
      register_class_with_limit m, %r{\Aimage}i,        ImageType
      register_class_with_limit m, %r{\Abinary}i,       BinaryType
      register_class_with_limit m, %r{\Avarbinary}i,    VarbinaryType
      # m.register_type              'varbinary(max)',    VarbinaryMaxType.new
      # Other Data Types
      m.register_type              'uniqueidentifier',  UUIDType.new
      # TODO
      # m.register_type              'timestamp',         SQLServer::Type::Timestamp.new
      m.register_type              'xml',               XmlType.new
    end
  end

end
