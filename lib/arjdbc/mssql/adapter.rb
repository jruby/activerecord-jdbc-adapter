# NOTE: file contains code adapted from **sqlserver** adapter, license follows
=begin
Copyright (c) 2008-2015

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

ArJdbc.load_java_part :MSSQL

require 'arjdbc/abstract/core'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/statement_cache'
require 'arjdbc/util/quoted_cache'

class Arel::Visitors::SQLServer
  # sqlserver gem converts bind argument markers "?" to "@n", but JDBC wants "?".
  remove_method :visit_Arel_Nodes_BindParam
end

class ActiveRecord::ConnectionAdapters::SQLServer::Type::Date

  # Currently only called by our custom Time type for formatting
  def _formatted(value)
    value.to_s(:_sqlserver_dateformat)
  end

  # @Override
  # We do not want the DateTime object to be turned into a string
  def serialize(value)
    value = super
    value.present? ? ArJdbc::MSSQL::DateTime._jd_with_sql_type(value, self) : value
  end

end

class ActiveRecord::ConnectionAdapters::SQLServer::Type::DateTime

  #Still need to do this for Date and time

  # Currently only called by our custom Time type for formatting
  def _formatted(value)
    "#{value.to_s(:_sqlserver_datetime)}.#{quote_fractional(value)}"
  end

  # @Override
  # We do not want the Time object to be turned into a string
  def serialize(value)
    value = super
    value.acts_like?(:time) ? ArJdbc::MSSQL::Time._at_with_sql_type(value, self) : value
  end

end

class ActiveRecord::ConnectionAdapters::SQLServer::Type::Time

  # Currently only called from our custom Time type for formatting
  def _formatted(value)
    "#{value.to_s(:_sqlserver_time)}.#{quote_fractional(value)}"
  end

  # @Override
  # We do not want the Time object to be turned into a string
  def serialize(value)
    value = super
    value.acts_like?(:time) ? ArJdbc::MSSQL::Time._at_with_sql_type(value, self) : value
  end

end

module ArJdbc
  module MSSQL

    # Create our own DateTime class so that we can format strings properly and still have a DateTime class
    # for the jdbc driver to work with
    class DateTime < ::DateTime

      attr_accessor :_sql_type

      def self._jd_with_sql_type(value, type)
        jd(value.jd).tap { |t|  t._sql_type = type }
      end

      def to_s(*args)
        return super unless args.empty?
        _sql_type._formatted(self)
      end

    end

    # Create our own Time class so that we can format strings properly and still have a Time class
    # for the jdbc driver to work with
    class Time < ::Time

      attr_accessor :_sql_type

      def self._at_with_sql_type(value, type)
        new(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.min,
            value.sec + (Rational(value.nsec, 1000) / 1000000),
            value.gmt_offset
        ).tap { |t| t._sql_type = type }
      end

      def to_s(*args)
        return super unless args.empty?
        _sql_type._formatted(self)
      end

    end

    module AROverrides

      # Override
      def select(sql, name = nil, binds = [])
        exec_query(sql, name, binds, prepare: false) || [] # sqlserver gem expects a response instead of nil
      end

    end

    module SQLServerOverrides

      # @Override
      def disconnect!
        super
        # The gem expects these to disappear on disconnect
        @connection = nil
        @spid = nil
        @collation = nil
      end

      # Needed to reapply this since the jdbc abstract versions don't do the check and
      # end up overriding the sqlserver gem's version
      def exec_insert(sql, name, binds, pk = nil, _sequence_name = nil)
        if id_insert_table_name = exec_insert_requires_identity?(sql, pk, binds)
          with_identity_insert_enabled(id_insert_table_name) { super }
        else
          super
        end
      end

      # Needed to reapply this since the jdbc abstract versions don't do the check and
      # end up overriding the sqlserver gem's version
      def execute(sql, name = nil)
        if id_insert_table_name = query_requires_identity_insert?(sql)
          with_identity_insert_enabled(id_insert_table_name) { super }
        else
          super
        end
      end

      # FIXME Make this use the jdbc method of calling stored procedures
      def execute_procedure(proc_name, *variables)
        vars = if variables.any? && variables.first.is_a?(Hash)
                 variables.first.map { |k, v| "@#{k} = #{quote(v)}" }
               else
                 variables.map { |v| quote(v) }
               end.join(', ')
        sql = "EXEC #{proc_name} #{vars}".strip
        log(sql, 'Execute Procedure') do
          result = @connection.execute_query_raw(sql) # This call needed to be made differently
          result.map! do |row|
            row = row.is_a?(Hash) ? row.with_indifferent_access : row
            yield(row) if block_given?
            row
          end
          result
        end
      end

      # @Override
      # MSSQL does not return query plans for prepared statements, so we have to unprepare them
      # SQLServer gem handles this by overridding exec_explain but that doesn't correctly unprepare them for our needs
      def explain(arel, binds = [])
        arel = ActiveRecord::Base.send(:replace_bind_variables, arel, binds.map(&:value_for_database))
        super(arel, [])
      end

      # Override
      # Since we aren't passing dates/times around as strings we need to
      # process them here, just making sure they are a string
      def quoted_date(value)
        super.to_s
      end

      # Override
      # Make sure we set up the connection again
      def reconnect!
        super
        connect
      end

      protected

      def translate_exception(exception, message)
        return ActiveRecord::ValueTooLong.new(message) if exception.message.include?('java.sql.DataTruncation')
        super
      end

    end

  end
end

module ActiveRecord::ConnectionAdapters

  module SQLServer::CoreExt::Explain
    remove_method(:exec_explain) # This messes with the queries before passing them to main explain method
  end

  class SQLServerAdapter

    # The sqlserver gem's version of these needs to be taken out of the lookup chain
    remove_method(:disconnect!)
    remove_method(:reconnect!)

    prepend ArJdbc::Abstract::ConnectionManagement
    prepend ArJdbc::Abstract::Core
    prepend ArJdbc::Abstract::DatabaseStatements
    prepend ArJdbc::Abstract::StatementCache
    prepend ArJdbc::Abstract::TransactionSupport
    prepend ArJdbc::MSSQL::AROverrides
    prepend ArJdbc::MSSQL::SQLServerOverrides

    include ::ArJdbc::Util::QuotedCache

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def jdbc_connection_class(spec)
      ::ActiveRecord::ConnectionAdapters::MSSQLJdbcConnection
    end

    # @Overwrite
    def reset!
      clear_cache!
      reset_transaction
      @connection.rollback # Have to deal with rollbacks differently than the SQLServer gem
      @connection.configure_connection
    end

    # @Overwrite
    # Had some special logic and skipped using gem's internal query methods
    def select_rows(sql, name = nil, binds = [])

      # In some cases the limit is converted to a `TOP(1)` but the bind parameter is still in the array
      if !binds.empty? && sql.include?('TOP(1)')
        binds = binds.delete_if {|b| b.name == 'LIMIT' }
      end

      exec_query(sql, name, binds).rows
    end

    protected


    # @Overwrite
    # The only reason we have to override this is because if we are using
    # prepared statements, it forces params to @n format...
    def column_definitions(table_name)
      identifier = if database_prefix_remote_server?
                     SQLServer::Utils.extract_identifiers("#{database_prefix}#{table_name}")
                   else
                     SQLServer::Utils.extract_identifiers(table_name)
                   end
      database    = identifier.fully_qualified_database_quoted
      view_exists = view_exists?(table_name)
      view_tblnm  = view_table_name(table_name) if view_exists
      sql = %{
            SELECT DISTINCT
            #{lowercase_schema_reflection_sql('columns.TABLE_NAME')} AS table_name,
            #{lowercase_schema_reflection_sql('columns.COLUMN_NAME')} AS name,
            columns.DATA_TYPE AS type,
            columns.COLUMN_DEFAULT AS default_value,
            columns.NUMERIC_SCALE AS numeric_scale,
            columns.NUMERIC_PRECISION AS numeric_precision,
            columns.DATETIME_PRECISION AS datetime_precision,
            columns.COLLATION_NAME AS [collation],
            columns.ordinal_position,
            CASE
              WHEN columns.DATA_TYPE IN ('nchar','nvarchar','char','varchar') THEN columns.CHARACTER_MAXIMUM_LENGTH
              ELSE COL_LENGTH('#{database}.'+columns.TABLE_SCHEMA+'.'+columns.TABLE_NAME, columns.COLUMN_NAME)
            END AS [length],
            CASE
              WHEN columns.IS_NULLABLE = 'YES' THEN 1
              ELSE NULL
            END AS [is_nullable],
            CASE
              WHEN KCU.COLUMN_NAME IS NOT NULL AND TC.CONSTRAINT_TYPE = N'PRIMARY KEY' THEN 1
              ELSE NULL
            END AS [is_primary],
            c.is_identity AS [is_identity]
            FROM #{database}.INFORMATION_SCHEMA.COLUMNS columns
            LEFT OUTER JOIN #{database}.INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS TC
              ON TC.TABLE_NAME = columns.TABLE_NAME
              AND TC.TABLE_SCHEMA = columns.TABLE_SCHEMA
              AND TC.CONSTRAINT_TYPE = N'PRIMARY KEY'
            LEFT OUTER JOIN #{database}.INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS KCU
              ON KCU.COLUMN_NAME = columns.COLUMN_NAME
              AND KCU.CONSTRAINT_NAME = TC.CONSTRAINT_NAME
              AND KCU.CONSTRAINT_CATALOG = TC.CONSTRAINT_CATALOG
              AND KCU.CONSTRAINT_SCHEMA = TC.CONSTRAINT_SCHEMA
            INNER JOIN #{database}.sys.schemas AS s
              ON s.name = columns.TABLE_SCHEMA
              AND s.schema_id = s.schema_id
            INNER JOIN #{database}.sys.objects AS o
              ON s.schema_id = o.schema_id
              AND o.is_ms_shipped = 0
              AND o.type IN ('U', 'V')
              AND o.name = columns.TABLE_NAME
            INNER JOIN #{database}.sys.columns AS c
              ON o.object_id = c.object_id
              AND c.name = columns.COLUMN_NAME
            WHERE columns.TABLE_NAME = #{prepared_statements ? '?' : quote(identifier.object)}
              AND columns.TABLE_SCHEMA = #{identifier.schema.blank? ? 'schema_name()' : (prepared_statements ? '?' : quote(identifier.schema))}
            ORDER BY columns.ordinal_position
          }.gsub(/[ \t\r\n]+/, ' ').strip
      binds = []
      nv128 = SQLServer::Type::UnicodeVarchar.new limit: 128
      binds << ActiveRecord::Relation::QueryAttribute.new('TABLE_NAME', identifier.object, nv128)
      binds << ActiveRecord::Relation::QueryAttribute.new('TABLE_SCHEMA', identifier.schema, nv128) unless identifier.schema.blank?
      results = exec_query(sql, 'SCHEMA', binds)
      results.map do |ci|
        ci = ci.symbolize_keys
        ci[:_type] = ci[:type]
        ci[:table_name] = view_tblnm || table_name
        ci[:type] = case ci[:type]
                    when /^bit|image|text|ntext|datetime$/
                      ci[:type]
                    when /^datetime2|datetimeoffset$/i
                      "#{ci[:type]}(#{ci[:datetime_precision]})"
                    when /^time$/i
                      "#{ci[:type]}(#{ci[:datetime_precision]})"
                    when /^numeric|decimal$/i
                      "#{ci[:type]}(#{ci[:numeric_precision]},#{ci[:numeric_scale]})"
                    when /^float|real$/i
                      "#{ci[:type]}"
                    when /^char|nchar|varchar|nvarchar|binary|varbinary|bigint|int|smallint$/
                      ci[:length].to_i == -1 ? "#{ci[:type]}(max)" : "#{ci[:type]}(#{ci[:length]})"
                    else
                      ci[:type]
                    end
        ci[:default_value], ci[:default_function] = begin
          default = ci[:default_value]
          if default.nil? && view_exists
            default = select_value "
                  SELECT c.COLUMN_DEFAULT
                  FROM #{database}.INFORMATION_SCHEMA.COLUMNS c
                  WHERE c.TABLE_NAME = '#{view_tblnm}'
                  AND c.COLUMN_NAME = '#{views_real_column_name(table_name, ci[:name])}'".squish, 'SCHEMA'
          end
          case default
          when nil
            [nil, nil]
          when /\A\((\w+\(\))\)\Z/
            default_function = Regexp.last_match[1]
            [nil, default_function]
          when /\A\(N'(.*)'\)\Z/m
            string_literal = SQLServer::Utils.unquote_string(Regexp.last_match[1])
            [string_literal, nil]
          when /CREATE DEFAULT/mi
            [nil, nil]
          else
            type = case ci[:type]
                   when /smallint|int|bigint/ then ci[:_type]
                   else ci[:type]
                   end
            value = default.match(/\A\((.*)\)\Z/m)[1]
            value = select_value "SELECT CAST(#{value} AS #{type}) AS value", 'SCHEMA'
            [value, nil]
          end
        end
        ci[:null] = ci[:is_nullable].to_i == 1
        ci.delete(:is_nullable)
        ci[:is_primary] = ci[:is_primary].to_i == 1
        ci[:is_identity] = ci[:is_identity].to_i == 1 unless [TrueClass, FalseClass].include?(ci[:is_identity].class)
        ci
      end
    end

    # @Overwrite
    # Makes a connection before configuring it
    # @connection actually gets defined and then the connect method in the sqlserver gem overrides it
    # This can probably be fixed with a patch to the main gem
    def connect
      @spid = @connection.execute('SELECT @@SPID').first.values.first
      @version_year = version_year # Not sure if this is necessary but kept it this way because the gem has it this way
      configure_connection
    end

    # @Overwrite
    # This ends up as a no-op without the override
    def do_execute(sql, name = 'SQL')
      execute(sql, name)
    end

    # @Overwrite
    # Overriding this in case it gets used in places that we don't override by default
    def raw_connection_do(sql)
      @connection.execute(sql)
    ensure
      @update_sql = false
    end

    # @Overwrite
    # This is not used in most cases, but override it for the handful of places that are still left
    def sp_executesql(sql, name, binds, _options = {})
      exec_query(sql, name, binds)
    end

    # @Overwrite
    # Prevents turning an insert statement into a query with results
    # Slightly adjusted since we know there should always be a table name in the sql
    def sql_for_insert(sql, pk, id_value, sequence_name, binds)
      pk = primary_key(get_table_name(sql)) if pk.nil?
      [sql, binds, pk, sequence_name]
    end

    # @Overwrite
    # Made it so we don't use the internal calls from the gem
    def version_year
      return @version_year if defined?(@version_year)
      @version_year = begin
        vstring = select_value('SELECT @@version').to_s
        return 2016 if vstring =~ /vNext/
        /SQL Server (\d+)/.match(vstring).to_a.last.to_s.to_i
      rescue Exception => e
        2016
      end
    end

  end

end
