ArJdbc.load_java_part :Oracle

require 'arjdbc/oracle/column'

module ArJdbc
  module Oracle

    # @private
    def self.extended(adapter); initialize!; end

    # @private
    @@_initialized = nil

    # @private
    def self.initialize!
      return if @@_initialized; @@_initialized = true

      require 'arjdbc/jdbc/serialized_attributes_helper'
      ActiveRecord::Base.class_eval do
        def after_save_with_oracle_lob
          self.class.columns.select { |c| c.sql_type =~ /LOB\(|LOB$/i }.each do |column|
            value = ::ArJdbc::SerializedAttributesHelper.dump_column_value(self, column)
            next if value.nil? || (value == '')

            self.class.connection.update_lob_value(self, column, value)
          end
        end
      end
      ActiveRecord::Base.after_save :after_save_with_oracle_lob

      unless ActiveRecord::ConnectionAdapters::AbstractAdapter.
          instance_methods(false).detect { |m| m.to_s == "prefetch_primary_key?" }
        require 'arjdbc/jdbc/quoted_primary_key'
        ActiveRecord::Base.extend ArJdbc::QuotedPrimaryKeyExtension
      end
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::OracleJdbcConnection
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_column_class
    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::OracleColumn
    end

    # @private
    @@emulate_booleans = true

    # Boolean emulation can be disabled using :
    #
    #   ArJdbc::Oracle.emulate_booleans = false
    #
    # @see ActiveRecord::ConnectionAdapters::OracleAdapter#emulate_booleans
    def self.emulate_booleans; @@emulate_booleans; end
    def self.emulate_booleans=(emulate); @@emulate_booleans = emulate; end

    class TableDefinition < ::ActiveRecord::ConnectionAdapters::TableDefinition
      def raw(*args)
        options = args.extract_options!
        column(args[0], 'raw', options)
      end

      def xml(*args)
        options = args.extract_options!
        column(args[0], 'xml', options)
      end
    end

    def table_definition(*args)
      new_table_definition(TableDefinition, *args)
    end

    def self.arel_visitor_type(config = nil)
      ::Arel::Visitors::Oracle
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#bind_substitution
    # @private
    class BindSubstitution < ::Arel::Visitors::Oracle
      include ::Arel::Visitors::BindVisitor
    end if defined? ::Arel::Visitors::BindVisitor

    ADAPTER_NAME = 'Oracle'.freeze

    def adapter_name
      ADAPTER_NAME
    end

    NATIVE_DATABASE_TYPES = {
      :primary_key => "NUMBER(38) NOT NULL PRIMARY KEY",
      :string => { :name => "VARCHAR2", :limit => 255 },
      :text => { :name => "CLOB" },
      :integer => { :name => "NUMBER", :limit => 38 },
      :float => { :name => "NUMBER" },
      :decimal => { :name => "DECIMAL" },
      :datetime => { :name => "DATE" },
      :timestamp => { :name => "TIMESTAMP" },
      :time => { :name => "DATE" },
      :date => { :name => "DATE" },
      :binary => { :name => "BLOB" },
      :boolean => { :name => "NUMBER", :limit => 1 },
      :raw => { :name => "RAW", :limit => 2000 },
      :xml => { :name => 'XMLTYPE' }
    }

    def native_database_types
      super.merge(NATIVE_DATABASE_TYPES)
    end

    def modify_types(types)
      super(types)
      NATIVE_DATABASE_TYPES.each do |key, value|
        types[key] = value.dup
      end
      types
    end

    # Prevent ORA-01795 for in clauses with more than 1000
    def in_clause_length
      1000
    end
    alias_method :ids_in_list_limit, :in_clause_length

    IDENTIFIER_LENGTH = 30

    # maximum length of Oracle identifiers is 30
    def table_alias_length; IDENTIFIER_LENGTH; end
    def table_name_length;  IDENTIFIER_LENGTH; end
    def index_name_length;  IDENTIFIER_LENGTH; end
    def column_name_length; IDENTIFIER_LENGTH; end

    def default_sequence_name(table_name, column = nil)
      # TODO: remove schema prefix if present (before truncating)
      "#{table_name.to_s[0, IDENTIFIER_LENGTH - 4]}_seq"
    end

    # @override
    def create_table(name, options = {})
      super(name, options)
      unless options[:id] == false
        seq_name = options[:sequence_name] || default_sequence_name(name)
        start_value = options[:sequence_start_value] || 10000
        raise ActiveRecord::StatementInvalid.new("name #{seq_name} too long") if seq_name.length > table_alias_length
        execute "CREATE SEQUENCE #{quote_table_name(seq_name)} START WITH #{start_value}"
      end
    end

    # @override
    def rename_table(name, new_name)
      if new_name.to_s.length > table_name_length
        raise ArgumentError, "New table name '#{new_name}' is too long; the limit is #{table_name_length} characters"
      end
      if "#{new_name}_seq".to_s.length > sequence_name_length
        raise ArgumentError, "New sequence name '#{new_name}_seq' is too long; the limit is #{sequence_name_length} characters"
      end
      execute "RENAME #{quote_table_name(name)} TO #{quote_table_name(new_name)}"
      execute "RENAME #{quote_table_name("#{name}_seq")} TO #{quote_table_name("#{new_name}_seq")}" rescue nil
    end

    # @override
    def drop_table(name, options = {})
      super(name)
      seq_name = options[:sequence_name] || default_sequence_name(name)
      execute "DROP SEQUENCE #{quote_table_name(seq_name)}" rescue nil
    end

    # @override
    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      case type.to_sym
      when :binary
        # { BLOB | BINARY LARGE OBJECT } [ ( length [{K |M |G }] ) ]
        # although Oracle does not like limit (length) with BLOB (or CLOB) :
        #
        # CREATE TABLE binaries (data BLOB, short_data BLOB(1024));
        # ORA-00907: missing right parenthesis             *
        #
        # TODO do we need to worry about NORMAL vs. non IN-TABLE BLOBs ?!
        # http://dba.stackexchange.com/questions/8770/improve-blob-writing-performance-in-oracle-11g
        # - if the LOB is smaller than 3900 bytes it can be stored inside the
        #   table row; by default this is enabled,
        #   unless you specify DISABLE STORAGE IN ROW
        # - normal LOB - stored in a separate segment, outside of table,
        #   you may even put it in another tablespace;
        super(type, nil, nil, nil)
      when :text
        super(type, nil, nil, nil)
      else
        super
      end
    end

    def sql_literal?(value)
      defined?(::Arel::SqlLiteral) && ::Arel::SqlLiteral === value
    end
    private :sql_literal?

    def indexes(table, name = nil)
      @connection.indexes(table, name, @connection.connection.meta_data.user_name)
    end

    # @note Only used with (non-AREL) ActiveRecord **2.3**.
    # @see Arel::Visitors::Oracle
    def add_limit_offset!(sql, options)
      offset = options[:offset] || 0
      if limit = options[:limit]
        sql.replace "SELECT * FROM " <<
          "(select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_ where rownum <= #{offset + limit})" <<
          " WHERE raw_rnum_ > #{offset}"
      elsif offset > 0
        sql.replace "SELECT * FROM " <<
          "(select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_)" <<
          " WHERE raw_rnum_ > #{offset}"
      end
    end if ::ActiveRecord::VERSION::MAJOR < 3

    def current_user
      @current_user ||= execute("SELECT sys_context('userenv', 'session_user') su FROM dual").first['su']
    end

    def current_database
      @current_database ||= execute("SELECT sys_context('userenv', 'db_name') db FROM dual").first['db']
    end

    def current_schema
      execute("SELECT sys_context('userenv', 'current_schema') schema FROM dual").first['schema']
    end

    def current_schema=(schema_owner)
      execute("ALTER SESSION SET current_schema=#{schema_owner}")
    end

    # @override
    def release_savepoint(name = nil)
      # no RELEASE SAVEPOINT statement in Oracle (JDBC driver throws "Unsupported feature")
    end

    def remove_index(table_name, options = {})
      execute "DROP INDEX #{index_name(table_name, options)}"
    end

    def change_column_default(table_name, column_name, default)
      execute "ALTER TABLE #{quote_table_name(table_name)} " +
        "MODIFY #{quote_column_name(column_name)} DEFAULT #{quote(default)}"
    end

    # @override
    def add_column_options!(sql, options)
      # handle case  of defaults for CLOB columns, which would otherwise get "quoted" incorrectly
      if options_include_default?(options) && (column = options[:column]) && column.type == :text
        sql << " DEFAULT #{quote(options.delete(:default))}"
      end
      super
    end

    # @override
    def change_column(table_name, column_name, type, options = {})
      change_column_sql = "ALTER TABLE #{quote_table_name(table_name)} " <<
        "MODIFY #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit])}"
      add_column_options!(change_column_sql, options)
      execute(change_column_sql)
    end

    # @override
    def rename_column(table_name, column_name, new_column_name)
      execute "ALTER TABLE #{quote_table_name(table_name)} " <<
        "RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
    end

    # @override
    def remove_column(table_name, *column_names)
      for column_name in column_names.flatten
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP COLUMN #{quote_column_name(column_name)}"
      end
    end

    # SELECT DISTINCT clause for a given set of columns and a given ORDER BY clause.
    #
    # Oracle requires the ORDER BY columns to be in the SELECT list for DISTINCT
    # queries. However, with those columns included in the SELECT DISTINCT list, you
    # won't actually get a distinct list of the column you want (presuming the column
    # has duplicates with multiple values for the ordered-by columns. So we use the
    # FIRST_VALUE function to get a single (first) value for each column, effectively
    # making every row the same.
    #
    #   distinct("posts.id", "posts.created_at desc")
    def distinct(columns, order_by)
      return "DISTINCT #{columns}" if order_by.blank?

      # construct a valid DISTINCT clause, ie. one that includes the ORDER BY columns, using
      # FIRST_VALUE such that the inclusion of these columns doesn't invalidate the DISTINCT
      order_columns = extract_order_columns(order_by).map do |c, i|
        "FIRST_VALUE(#{c.split.first}) OVER (PARTITION BY #{columns} ORDER BY #{c}) AS alias_#{i}__"
      end
      sql = "DISTINCT #{columns}, "
      sql << order_columns * ", "
    end

    # ORDER BY clause for the passed order option.
    #
    # Uses column aliases as defined by {#distinct}.
    def add_order_by_for_association_limiting!(sql, options)
      return sql if options[:order].blank?

      order_columns = extract_order_columns(options[:order]) do |columns|
        columns.map! { |s| $1 if s =~ / (.*)/ }; columns
      end
      order = order_columns.map { |s, i| "alias_#{i}__ #{s}" } # @see {#distinct}

      sql << "ORDER BY #{order.join(', ')}"
    end

    def extract_order_columns(order_by)
      columns = order_by.split(',')
      columns.map!(&:strip); columns.reject!(&:blank?)
      columns = yield(columns) if block_given?
      columns.zip( (0...columns.size).to_a )
    end
    private :extract_order_columns

    def temporary_table?(table_name)
      select_value("SELECT temporary FROM user_tables WHERE table_name = '#{table_name.upcase}'") == 'Y'
    end

    def tables
      @connection.tables(nil, oracle_schema)
    end

    # NOTE: better to use current_schema instead of the configured one ?!
    def columns(table_name, name = nil)
      @connection.columns_internal(table_name.to_s, nil, oracle_schema)
    end

    def tablespace(table_name)
      select_value "SELECT tablespace_name FROM user_tables WHERE table_name='#{table_name.to_s.upcase}'"
    end

    def charset
      database_parameters['NLS_CHARACTERSET']
    end

    def collation
      database_parameters['NLS_COMP']
    end

    def database_parameters
      return @database_parameters unless ( @database_parameters ||= {} ).empty?
      @connection.execute_query_raw("SELECT * FROM NLS_DATABASE_PARAMETERS") do
        |name, value| @database_parameters[name] = value
      end
      @database_parameters
    end

    # QUOTING ==================================================

    # @override
    def quote_table_name(name)
      name.to_s.split('.').map{ |n| n.split('@').map{ |m| quote_column_name(m) }.join('@') }.join('.')
    end

    # @override
    def quote_column_name(name)
      # if only valid lowercase column characters in name
      if ( name = name.to_s ) =~ /\A[a-z][a-z_0-9\$#]*\Z/
        # putting double-quotes around an identifier causes Oracle to treat the
        # identifier as case sensitive (otherwise assumes case-insensitivity) !
        # all upper case is an exception, where double-quotes are meaningless
        "\"#{name.upcase}\"" # name.upcase
      else
        # remove double quotes which cannot be used inside quoted identifier
        "\"#{name.gsub('"', '')}\""
      end
    end

    def unquote_table_name(name)
      name = name[1...-1] if name[0, 1] == '"'
      name.upcase == name ? name.downcase : name
    end

    # @override
    def quote(value, column = nil)
      return value if sql_literal?(value) # Arel 2 passes SqlLiterals through

      column_type = column && column.type
      if column_type == :text || column_type == :binary
        if /(.*?)\([0-9]+\)/ =~ column.sql_type
          %Q{empty_#{ $1.downcase }()}
        else
          %Q{empty_#{ column.sql_type.downcase rescue 'blob' }()}
        end
      elsif column_type == :xml
        "XMLTYPE('#{quote_string(value)}')" # XMLTYPE ?
      elsif column_type == :raw
        quote_raw(value)
      else
        if column.respond_to?(:primary) && column.primary && column.klass != String
          return value.to_i.to_s
        end

        if column_type == :datetime || column_type == :time
          if value.acts_like?(:time)
            %Q{TO_DATE('#{get_time(value).strftime("%Y-%m-%d %H:%M:%S")}','YYYY-MM-DD HH24:MI:SS')}
          else
            value.blank? ? 'NULL' : %Q{DATE'#{value}'} # assume correctly formated DATE (string)
          end
        elsif ( like_date = value.acts_like?(:date) ) || column_type == :date
          if value.acts_like?(:time) # value.respond_to?(:strftime)
            %Q{DATE'#{get_time(value).strftime("%Y-%m-%d")}'}
          elsif like_date
            %Q{DATE'#{quoted_date(value)}'} # DATE 'YYYY-MM-DD'
          else
            value.blank? ? 'NULL' : %Q{DATE'#{value}'} # assume correctly formated DATE (string)
          end
        elsif ( like_time = value.acts_like?(:time) ) || column_type == :timestamp
          if like_time
            %Q{TIMESTAMP'#{quoted_date(value, true)}'} # TIMESTAMP 'YYYY-MM-DD HH24:MI:SS.FF'
          else
            value.blank? ? 'NULL' : %Q{TIMESTAMP'#{value}'} # assume correctly formated TIMESTAMP (string)
          end
        else
          super
        end
      end
    end

    # Quote date/time values for use in SQL input.
    # Includes milliseconds if the value is a Time responding to usec.
    # @override
    def quoted_date(value, time = nil)
      if time || ( time.nil? && value.acts_like?(:time) )
        usec = value.respond_to?(:usec) && (value.usec / 10000.0).round # .428000 -> .43
        return "#{get_time(value).to_s(:db)}.#{sprintf("%02d", usec)}" if usec
        # value.strftime("%Y-%m-%d %H:%M:%S")
      end
      value.to_s(:db)
    end

    def quote_raw(value)
      value = value.unpack('C*') if value.is_a?(String)
      "'#{value.map { |x| "%02X" % x }.join}'"
    end

    # @override
    def supports_migrations?
      true
    end

    # @override
    def supports_primary_key?
      true
    end

    # @override
    def supports_savepoints?
      true
    end

    # @override
    def supports_explain?
      true
    end

    def explain(arel, binds = [])
      sql = "EXPLAIN PLAN FOR #{to_sql(arel)}"
      return if sql =~ /FROM all_/
      execute(sql, 'EXPLAIN', binds)
      select_values("SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY)", 'EXPLAIN').join("\n")
    end

    def select(sql, name = nil, binds = [])
      result = super # AR::Result (4.0) or Array (<= 3.2)
      result.columns.delete('raw_rnum_') if result.respond_to?(:columns)
      result.each { |row| row.delete('raw_rnum_') } # Hash rows even for AR::Result
      result
    end

    # Returns true for Oracle adapter (since Oracle requires primary key
    # values to be pre-fetched before insert).
    # @see #next_sequence_value
    # @override
    def prefetch_primary_key?(table_name = nil)
      return true if table_name.nil?
      table_name = table_name.to_s
      columns(table_name).detect { |column| column.primary }
    end

    # @override
    def next_sequence_value(sequence_name)
      sequence_name = quote_table_name(sequence_name)
      sql = "SELECT #{sequence_name}.NEXTVAL id FROM dual"
      log(sql, 'SQL') { @connection.next_sequence_value(sequence_name) }
    end

    # @override (for AR <= 3.0)
    def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
      # if PK is already pre-fetched from sequence or if there is no PK :
      if id_value || pk.nil?
        execute(sql, name)
        return id_value
      end

      if pk && use_insert_returning? # true by default on AR <= 3.0
        sql = "#{sql} RETURNING #{quote_column_name(pk)}"
      end
      execute(sql, name)
    end
    protected :insert_sql

    # @override
    def sql_for_insert(sql, pk, id_value, sequence_name, binds)
      unless id_value || pk.nil?
        if pk && use_insert_returning?
          sql = "#{sql} RETURNING #{quote_column_name(pk)}"
        end
      end
      [ sql, binds ]
    end

    # @override
    def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
      # NOTE: ActiveRecord::Relation calls our {#next_sequence_value}
      # (from its `insert`) and passes the returned id_value here ...
      sql, binds = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)
      if id_value
        exec_update(sql, name, binds)
        return id_value
      else
        value = exec_insert(sql, name, binds, pk, sequence_name)
        id_value || last_inserted_id(value)
      end
    end

    # @override
    def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
      if pk && use_insert_returning?
        exec_query(sql, name, binds) # due RETURNING clause
      else
        super(sql, name, binds) # assume no generated id for table
      end
    end

    def next_id_value(sql, sequence_name = nil)
      # Assume the SQL contains a bind-variable for the ID
      sequence_name ||= begin
        # Extract the table from the insert SQL. Yuck.
        table = extract_table_ref_from_insert_sql(sql)
        default_sequence_name(table)
      end
      next_sequence_value(sequence_name)
    end
    private :next_id_value

    def use_insert_returning?
      if ( @use_insert_returning ||= nil ).nil?
        @use_insert_returning = false
      end
      @use_insert_returning
    end

    private

    def _execute(sql, name = nil)
      if self.class.select?(sql)
        @connection.execute_query_raw(sql)
      elsif self.class.insert?(sql)
        @connection.execute_insert(sql)
      else
        @connection.execute_update(sql)
      end
    end

    def extract_table_ref_from_insert_sql(sql)
      table = sql.split(" ", 4)[2]
      if idx = table.index('(')
        table = table[0...idx] # INTO table(col1, col2) ...
      end
      unquote_table_name(table)
    end

    # In Oracle, schemas are usually created under your username :
    # http://www.oracle.com/technology/obe/2day_dba/schema/schema.htm
    #
    # A schema is the set of objects (tables, views, indexes, etc) that belongs
    # to an user, often used as another way to refer to an Oracle user account.
    #
    # But allow separate configuration as "schema:" anyway (see #53)
    def oracle_schema
      if @config[:schema]
        @config[:schema].to_s
      elsif @config[:username]
        @config[:username].to_s
      end
    end

  end
end

require 'arjdbc/util/quoted_cache'

module ActiveRecord::ConnectionAdapters

  remove_const(:OracleAdapter) if const_defined?(:OracleAdapter)

  class OracleAdapter < JdbcAdapter
    include ::ArJdbc::Oracle
    include ::ArJdbc::Util::QuotedCache

    # By default, the MysqlAdapter will consider all columns of type
    # <tt>tinyint(1)</tt> as boolean. If you wish to disable this :
    #
    #   ActiveRecord::ConnectionAdapters::OracleAdapter.emulate_booleans = false
    #
    def self.emulate_booleans; ::ArJdbc::Oracle.emulate_booleans; end
    def self.emulate_booleans=(emulate); ::ArJdbc::Oracle.emulate_booleans = emulate; end

    def initialize(*args)
      ::ArJdbc::Oracle.initialize!
      super # configure_connection happens in super

      @use_insert_returning = config.key?(:insert_returning) ?
        self.class.type_cast_config_to_boolean(config[:insert_returning]) : nil
    end

  end

  class OracleColumn < JdbcColumn
    include ::ArJdbc::Oracle::Column
  end

end
