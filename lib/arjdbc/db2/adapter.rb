# NOTE: file contains code adapted from **ruby-ibmdb** adapter, license follows
=begin
Copyright (c) 2006 - 2015 IBM Corporation

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

ArJdbc.load_java_part :DB2

require 'arjdbc/db2/column'

module ArJdbc
  # @note This adapter doesn't support explain `config.active_record.auto_explain_threshold_in_seconds` should be commented (Rails < 4.0)
  module DB2

    # @private
    def self.extended(adapter); initialize!; end

    # @private
    @@_initialized = nil

    # @private
    def self.initialize!
      return if @@_initialized; @@_initialized = true

      require 'arjdbc/util/serialized_attributes'
      Util::SerializedAttributes.setup /blob|clob/i, 'after_save_with_db2_lob'
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::DB2JdbcConnection
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_column_class
    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::DB2Column
    end

    # @see ActiveRecord::ConnectionAdapters::Jdbc::ArelSupport
    def self.arel_visitor_type(config = nil)
      require 'arel/visitors/db2'; ::Arel::Visitors::DB2
    end

    # @deprecated no longer used
    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#arel2_visitors
    def self.arel2_visitors(config)
      { 'db2' => arel_visitor_type }
    end

    # @private
    @@emulate_booleans = true

    # Boolean emulation can be disabled using :
    #
    #   ArJdbc::DB2.emulate_booleans = false
    #
    def self.emulate_booleans?; @@emulate_booleans; end
    # @deprecated Use {#emulate_booleans?} instead.
    def self.emulate_booleans; @@emulate_booleans; end
    # @see #emulate_booleans?
    def self.emulate_booleans=(emulate); @@emulate_booleans = emulate; end

    # @private
    @@update_lob_values = true

    # Updating records with LOB values (binary/text columns) in a separate
    # statement can be disabled using :
    #
    #   ArJdbc::DB2.update_lob_values = false
    #
    # @note This only applies when prepared statements are not used.
    def self.update_lob_values?; @@update_lob_values; end
    # @see #update_lob_values?
    def self.update_lob_values=(update); @@update_lob_values = update; end

    # @see #update_lob_values?
    # @see ArJdbc::Util::SerializedAttributes#update_lob_columns
    def update_lob_value?(value, column = nil)
      DB2.update_lob_values? && ! prepared_statements? # && value
    end

    # @see #quote
    # @private
    BLOB_VALUE_MARKER = "BLOB('')"
    # @see #quote
    # @private
    CLOB_VALUE_MARKER = "''"

    def configure_connection
      schema = self.schema
      set_schema(schema) if schema && schema != config[:username]
    end

    ADAPTER_NAME = 'DB2'.freeze

    def adapter_name
      ADAPTER_NAME
    end

    NATIVE_DATABASE_TYPES = {
      :string     => { :name => "varchar", :limit => 255 },
      :integer    => { :name => "integer" },
      :bigint     => { :name => 'bigint' },
      :float      => { :name => "real" }, # :limit => 24
      :double     => { :name => "double" }, # :limit => 53
      :text       => { :name => "clob" },
      :binary     => { :name => "blob" },
      :xml        => { :name => "xml" },
      :decimal    => { :name => "decimal" }, # :limit => 31
      :char       => { :name => "char" }, # :limit => 254
      :date       => { :name => "date" },
      :datetime   => { :name => "timestamp" },
      :timestamp  => { :name => "timestamp" },
      :time       => { :name => "time" },
      :boolean    => { :name => "smallint" }, # no native boolean type
      #:rowid      => { :name => "rowid" }, # rowid is a supported datatype on z/OS and i/5
      #:serial     => { :name => "serial" }, # supported datatype on Informix Dynamic Server
      #:graphic    => { :name => "graphic", :limit => 1 }, # :limit => 127
    }

    # @override
    def initialize_type_map(m)
      register_class_with_limit m, %r(boolean)i,   ActiveRecord::Type::Boolean
      register_class_with_limit m, %r(char)i,      ActiveRecord::Type::String
      register_class_with_limit m, %r(binary)i,    ActiveRecord::Type::Binary
      register_class_with_limit m, %r(text)i,      ActiveRecord::Type::Text
      register_class_with_limit m, %r(date)i,      ActiveRecord::Type::Date
      register_class_with_limit m, %r(time)i,      ActiveRecord::Type::Time
      register_class_with_limit m, %r(datetime)i,  ActiveRecord::Type::DateTime
      register_class_with_limit m, %r(float)i,     ActiveRecord::Type::Float
      register_class_with_limit m, %r(int)i,       ActiveRecord::Type::Integer

      m.alias_type %r(blob)i,      'binary'
      m.alias_type %r(clob)i,      'text'
      m.alias_type %r(timestamp)i, 'datetime'
      m.alias_type %r(numeric)i,   'decimal'
      m.alias_type %r(number)i,    'decimal'
      m.alias_type %r(double)i,    'float'
      m.alias_type %r(real)i,      'float'

      m.register_type(%r(decimal)i) do |sql_type|
        scale = extract_scale(sql_type)
        precision = extract_precision(sql_type)
        limit = extract_limit(sql_type)
        if scale == 0
          ActiveRecord::Type::BigInteger.new(:precision => precision, :limit => limit)
        else
          ActiveRecord::Type::Decimal.new(:precision => precision, :scale => scale)
        end
      end

      m.alias_type %r(for bit data)i,  'binary'
      m.alias_type %r(smallint)i,      'boolean'
      m.alias_type %r(serial)i,        'int'
      m.alias_type %r(decfloat)i,      'decimal'
      #m.alias_type %r(real)i,          'decimal'
      m.alias_type %r(graphic)i,       'binary'
      m.alias_type %r(rowid)i,         'int'

      m.register_type(%r(smallint)i) do
        if DB2.emulate_booleans?
          ActiveRecord::Type::Boolean.new
        else
          ActiveRecord::Type::Integer.new(:limit => 1)
        end
      end

      m.register_type %r(xml)i, XmlType.new
    end if AR42

    # @private
    class XmlType < ActiveRecord::Type::String
      def type; :xml end

      def type_cast_for_database(value)
        return unless value
        Data.new(super)
      end

      class Data
        def initialize(value)
          @value = value
        end
        def to_s; @value end
      end
    end if AR42

    # @override
    def reset_column_information
      initialize_type_map(type_map)
    end if AR42

    # @override
    def native_database_types
      # NOTE: currently merging with what JDBC gives us since there's a lot
      # of DB2-like stuff we could be connecting e.g. "classic", Z/OS etc.
      # types = super
      types = super.merge(NATIVE_DATABASE_TYPES)
      types
    end

    # @private
    class TableDefinition < ::ActiveRecord::ConnectionAdapters::TableDefinition

      def xml(*args)
        options = args.extract_options!
        column(args[0], 'xml', options)
      end

      # IBM DB adapter (MRI) compatibility :

      # @private
      # @deprecated
      def double(*args)
        options = args.extract_options!
        column(args[0], 'double', options)
      end

      # @private
      def decfloat(*args)
        options = args.extract_options!
        column(args[0], 'decfloat', options)
      end

      def graphic(*args)
        options = args.extract_options!
        column(args[0], 'graphic', options)
      end

      # @private
      # @deprecated
      def vargraphic(*args)
        options = args.extract_options!
        column(args[0], 'vargraphic', options)
      end

      # @private
      # @deprecated
      def bigint(*args)
        options = args.extract_options!
        column(args[0], 'bigint', options)
      end

      def char(*args)
        options = args.extract_options!
        column(args[0], 'char', options)
      end
      # alias_method :character, :char

    end

    def table_definition(*args)
      new_table_definition(TableDefinition, *args)
    end

    def prefetch_primary_key?(table_name = nil)
      # TRUE if the table has no identity column
      names = table_name.upcase.split(".")
      sql = "SELECT 1 FROM SYSCAT.COLUMNS WHERE IDENTITY = 'Y' "
      sql << "AND TABSCHEMA = '#{names.first}' " if names.size == 2
      sql << "AND TABNAME = '#{names.last}'"
      select_one(sql).nil?
    end

    def next_sequence_value(sequence_name)
      select_value("SELECT NEXT VALUE FOR #{sequence_name} FROM sysibm.sysdummy1")
    end

    def create_table(name, options = {}, &block)
      if zos?
        zos_create_table(name, options, &block)
      else
        super
      end
    end

    def zos_create_table(name, options = {})
      table_definition = new_table_definition TableDefinition, name, options[:temporary], options[:options], options[:as]

      unless options[:id] == false
        table_definition.primary_key(options[:primary_key] || primary_key(name))
      end

      yield table_definition if block_given?

      # Clobs in DB2 Host have to be created after the Table with an auxiliary Table.
      clob_columns = []
      table_definition.columns.delete_if do |column|
        if column.type && column.type.to_sym == :text
          clob_columns << column; true
        end
      end

      drop_table(name, options) if options[:force] && table_exists?(name)

      create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
      create_sql << "#{quote_table_name(name)} ("
      create_sql << table_definition.to_sql
      create_sql << ") #{options[:options]}"
      if @config[:database] && @config[:tablespace]
        create_sql << " IN #{@config[:database]}.#{@config[:tablespace]}"
      end

      execute create_sql

      # Table definition is complete only when a unique index is created on the primary_key column for DB2 V8 on zOS
      # create index on id column if options[:id] is nil or id ==true
      # else check if options[:primary_key]is not nil then create an unique index on that column
      # TODO someone on Z/OS should test this out - also not needed for V9 ?
      #primary_column = options[:id] == true ? 'id' : options[:primary_key]
      #add_index(name, (primary_column || 'id').to_s, :unique => true)

      clob_columns.each do |clob_column|
        column_name = clob_column.name.to_s
        execute "ALTER TABLE #{name} ADD COLUMN #{column_name} clob"
        clob_table_name = "#{name}_#{column_name}_CD_"
        if @config[:database] && @config[:lob_tablespaces]
          in_lob_table_space = " IN #{@config[:database]}.#{@config[:lob_tablespaces][name.split(".")[1]]}"
        end
        execute "CREATE AUXILIARY TABLE #{clob_table_name} #{in_lob_table_space} STORES #{name} COLUMN #{column_name}"
        execute "CREATE UNIQUE INDEX #{clob_table_name} ON #{clob_table_name};"
      end
    end
    private :zos_create_table

    def pk_and_sequence_for(table)
      # In JDBC/DB2 side, only upcase names of table and column are handled.
      keys = super(table.upcase)
      if keys && keys[0]
        # In ActiveRecord side, only downcase names of table and column are handled.
        keys[0] = keys[0].downcase
      end
      keys
    end

    # Properly quotes the various data types.
    # @param value contains the data
    # @param column (optional) contains info on the field
    # @override
    def quote(value, column = nil)
      return value.quoted_id if value.respond_to?(:quoted_id)
      return value if sql_literal?(value)

      if column
        if column.respond_to?(:primary) && column.primary && column.klass != String
          return value.to_i.to_s
        end
        if value && (column.type.to_sym == :decimal || column.type.to_sym == :integer)
          return value.to_s
        end
      end

      column_type = column && column.type.to_sym

      case value
      when nil then 'NULL'
      when Numeric # IBM_DB doesn't accept quotes on numeric types
        # if the column type is text or string, return the quote value
        if column_type == :text || column_type == :string
          "'#{value}'"
        else
          value.to_s
        end
      when String, ActiveSupport::Multibyte::Chars
        if column_type == :binary && column.sql_type !~ /for bit data/i
          if update_lob_value?(value, column)
            value.nil? ? 'NULL' : BLOB_VALUE_MARKER # '@@@IBMBINARY@@@'"
          else
            "BLOB('#{quote_string(value)}')"
          end
        elsif column && column.sql_type =~ /clob/ # :text
          if update_lob_value?(value, column)
            value.nil? ? 'NULL' : CLOB_VALUE_MARKER # "'@@@IBMTEXT@@@'"
          else
            "'#{quote_string(value)}'"
          end
        elsif column_type == :xml
          value.nil? ? 'NULL' : "'#{quote_string(value)}'" # "'<ibm>@@@IBMXML@@@</ibm>'"
        else
          "'#{quote_string(value)}'"
        end
      when Symbol then "'#{quote_string(value.to_s)}'"
      when Time
        # AS400 doesn't support date in time column
        if column_type == :time
          quote_time(value)
        else
          super
        end
      else super
      end
    end

    # @override
    def quoted_date(value)
      if value.acts_like?(:time) && value.respond_to?(:usec)
        usec = sprintf("%06d", value.usec)
        value = ::ActiveRecord::Base.default_timezone == :utc ? value.getutc : value.getlocal
        "#{value.strftime("%Y-%m-%d %H:%M:%S")}.#{usec}"
      else
        super
      end
    end if ::ActiveRecord::VERSION::MAJOR >= 3

    def quote_time(value)
      value = ::ActiveRecord::Base.default_timezone == :utc ? value.getutc : value.getlocal
      # AS400 doesn't support date in time column
      "'#{value.strftime("%H:%M:%S")}'"
    end

    def quote_column_name(column_name)
      column_name.to_s
    end

    def modify_types(types)
      super(types)
      types[:primary_key] = 'int not null generated by default as identity (start with 1) primary key'
      types[:string][:limit] = 255
      types[:integer][:limit] = nil
      types[:boolean] = {:name => "decimal(1)"}
      types
    end

    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      limit = nil if type.to_sym == :integer
      super(type, limit, precision, scale)
    end

    # @private
    VALUES_DEFAULT = 'VALUES ( DEFAULT )' # NOTE: Arel::Visitors::DB2 uses this

    # @override
    def empty_insert_statement_value
      VALUES_DEFAULT # won't work as DB2 needs to know the column count
    end

    def add_column(table_name, column_name, type, options = {})
      # The keyword COLUMN allows to use reserved names for columns (ex: date)
      add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      add_column_options!(add_column_sql, options)
      execute(add_column_sql)
    end

    def add_column_options!(sql, options)
      # handle case of defaults for CLOB columns,
      # which might get incorrect if we write LOBs in the after_save callback
      if options_include_default?(options)
        column = options[:column]
        if column && column.type == :text
          sql << " DEFAULT #{quote(options.delete(:default))}"
        end
        if column && column.type == :binary
          # quoting required for the default value of a column :
          value = options.delete(:default)
          # DB2 z/OS only allows NULL or "" (empty) string as DEFAULT value
          # for a BLOB column. non-empty string and non-NULL, return error!
          if value.nil?
            sql_value = "NULL"
          else
            sql_value = zos? ? "#{value}" : "BLOB('#{quote_string(value)}'"
          end
          sql << " DEFAULT #{sql_value}"
        end
      end
      super
    end

    # @note Only used with (non-AREL) ActiveRecord **2.3**.
    # @see Arel::Visitors::DB2
    def add_limit_offset!(sql, options)
      limit = options[:limit]
      replace_limit_offset!(sql, limit, options[:offset]) if limit
    end if ::ActiveRecord::VERSION::MAJOR < 3

    # @private shared with {Arel::Visitors::DB2}
    def replace_limit_offset!(sql, limit, offset, orders = nil)
      limit = limit.to_i

      if offset # && limit
        over_order_by = nil # NOTE: orders matching got reverted as it was not complete and there were no case covering it ...

        start_sql = "SELECT B.* FROM (SELECT A.*, row_number() OVER (#{over_order_by}) AS internal$rownum FROM (SELECT"
        end_sql = ") A ) B WHERE B.internal$rownum > #{offset} AND B.internal$rownum <= #{limit + offset.to_i}"

        if sql.is_a?(String)
          sql.sub!(/SELECT/i, start_sql)
          sql << end_sql
        else # AR 4.2 sql.class ... Arel::Collectors::Bind
          sql.parts[0] = start_sql # sql.sub! /SELECT/i
          sql.parts[ sql.parts.length ] = end_sql
        end
      else
        limit_sql = limit == 1 ? " FETCH FIRST ROW ONLY" : " FETCH FIRST #{limit} ROWS ONLY"
        if sql.is_a?(String)
          sql << limit_sql
        else # AR 4.2 sql.class ... Arel::Collectors::Bind
          sql.parts[ sql.parts.length ] = limit_sql
        end
      end
      sql
    end

    # @deprecated seems not sued nor tested ?!
    def runstats_for_table(tablename, priority = 10)
      @connection.execute_update "call sysproc.admin_cmd('RUNSTATS ON TABLE #{tablename} WITH DISTRIBUTION AND DETAILED INDEXES ALL UTIL_IMPACT_PRIORITY #{priority}')"
    end

    if ::ActiveRecord::VERSION::MAJOR >= 4

    def select(sql, name = nil, binds = [])
      exec_query(to_sql(suble_null_test(sql), binds), name, binds)
    end

    else

    def select(sql, name = nil, binds = [])
      exec_query_raw(to_sql(suble_null_test(sql), binds), name, binds)
    end

    end

    # @private
    IS_NOT_NULL = /(!=|<>)\s*NULL/i
    # @private
    IS_NULL = /=\s*NULL/i

    def suble_null_test(sql)
      return sql unless sql.is_a?(String)
      # DB2 does not like "= NULL", "!= NULL", or "<> NULL" :
      sql = sql.dup
      sql.gsub! IS_NOT_NULL, 'IS NOT NULL'
      sql.gsub! IS_NULL, 'IS NULL'
      sql
    end
    private :suble_null_test

    def add_index(table_name, column_name, options = {})
      if ! zos? || ( table_name.to_s == ActiveRecord::Migrator.schema_migrations_table_name.to_s )
        column_name = column_name.to_s if column_name.is_a?(Symbol)
        super
      else
        statement = 'CREATE'
        statement << ' UNIQUE ' if options[:unique]
        statement << " INDEX #{ActiveRecord::Base.table_name_prefix}#{options[:name]} "
        statement << " ON #{table_name}(#{column_name})"

        execute statement
      end
    end

    # @override
    def remove_index!(table_name, index_name)
      execute "DROP INDEX #{quote_column_name(index_name)}"
    end

    # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.admin.dbobj.doc/doc/t0020130.html
    # ...not supported on IBM i, so we raise in this case
    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      sql = "ALTER TABLE #{table_name} RENAME COLUMN #{column_name} TO #{new_column_name}"
      execute_table_change(sql, table_name, 'Rename Column')
    end

    def change_column_null(table_name, column_name, null)
      if null
        sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} DROP NOT NULL"
      else
        sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET NOT NULL"
      end
      execute_table_change(sql, table_name, 'Change Column')
    end

    def change_column_default(table_name, column_name, default)
      if default.nil?
        sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} DROP DEFAULT"
      else
        sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET WITH DEFAULT #{quote(default)}"
      end
      execute_table_change(sql, table_name, 'Change Column')
    end

    def change_column(table_name, column_name, type, options = {})
      data_type = type_to_sql(type, options[:limit], options[:precision], options[:scale])
      sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET DATA TYPE #{data_type}"
      execute_table_change(sql, table_name, 'Change Column')

      if options.include?(:default) and options.include?(:null)
        # which to run first?
        if options[:null] or options[:default].nil?
          change_column_null(table_name, column_name, options[:null])
          change_column_default(table_name, column_name, options[:default])
        else
          change_column_default(table_name, column_name, options[:default])
          change_column_null(table_name, column_name, options[:null])
        end
      elsif options.include?(:default)
        change_column_default(table_name, column_name, options[:default])
      elsif options.include?(:null)
        change_column_null(table_name, column_name, options[:null])
      end
    end

    if ActiveRecord::VERSION::MAJOR >= 4

    def remove_column(table_name, column_name, type = nil, options = {})
      db2_remove_column(table_name, column_name)
    end

    else

    def remove_column(table_name, *column_names)
      # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.admin.dbobj.doc/doc/t0020132.html
      outcome = nil
      column_names = column_names.flatten
      for column_name in column_names
        outcome = db2_remove_column(table_name, column_name)
      end
      column_names.size == 1 ? outcome : nil
    end

    end

    def rename_table(name, new_name)
      # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000980.html
      execute_table_change("RENAME TABLE #{name} TO #{new_name}", new_name, 'Rename Table')
    end

    def tables
      @connection.tables(nil, schema)
    end

    # only record precision and scale for types that can set them via CREATE TABLE:
    # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000927.html

    HAVE_LIMIT = %w(FLOAT DECFLOAT CHAR VARCHAR CLOB BLOB NCHAR NCLOB DBCLOB GRAPHIC VARGRAPHIC) # TIMESTAMP
    HAVE_PRECISION = %w(DECIMAL NUMERIC)
    HAVE_SCALE = %w(DECIMAL NUMERIC)

    def columns(table_name, name = nil)
      columns = @connection.columns_internal(table_name.to_s, nil, schema) # catalog == nil

      if zos?
        # Remove the mighty db2_generated_rowid_for_lobs from the list of columns
        columns = columns.reject { |col| "db2_generated_rowid_for_lobs" == col.name }
      end
      # scrub out sizing info when CREATE TABLE doesn't support it
      # but JDBC reports it (doh!)
      for column in columns
        base_sql_type = column.sql_type.sub(/\(.*/, "").upcase
        column.limit = nil unless HAVE_LIMIT.include?(base_sql_type)
        column.precision = nil unless HAVE_PRECISION.include?(base_sql_type)
        #column.scale = nil unless HAVE_SCALE.include?(base_sql_type)
      end

      columns
    end

    def indexes(table_name, name = nil)
      @connection.indexes(table_name, name, schema)
    end

    def recreate_database(name = nil, options = {})
      drop_database(name)
    end

    def drop_database(name = nil)
      tables.each { |table| drop_table("#{table}") }
    end

    def truncate(table_name, name = nil)
      execute "TRUNCATE TABLE #{quote_table_name(table_name)} IMMEDIATE", name
    end

    # @override
    def supports_views?; true end

    def execute_table_change(sql, table_name, name = nil)
      outcome = execute(sql, name)
      reorg_table(table_name, name)
      outcome
    end
    protected :execute_table_change

    def reorg_table(table_name, name = nil)
      exec_update "call sysproc.admin_cmd ('REORG TABLE #{table_name}')", name, []
    end
    private :reorg_table

    # alias_method :execute_and_auto_confirm, :execute

    # Returns the value of an identity column of the last *INSERT* statement
    # made over this connection.
    # @note Check the *IDENTITY_VAL_LOCAL* function for documentation.
    # @return [Fixnum]
    def last_insert_id
      @connection.identity_val_local
    end

    # NOTE: only setup query analysis on AR <= 3.0 since on 3.1 {#exec_query},
    # {#exec_insert} will be used for AR generated queries/inserts etc.
    # Also there's prepared statement support and {#execute} is meant to stay
    # as a way of running non-prepared SQL statements (returning raw results).
    if ActiveRecord::VERSION::MAJOR < 3 ||
      ( ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR < 1 )

    def _execute(sql, name = nil)
      if self.class.select?(sql)
        @connection.execute_query_raw(sql)
      elsif self.class.insert?(sql)
        @connection.execute_insert(sql) || last_insert_id
      else
        @connection.execute_update(sql)
      end
    end
    private :_execute

    end

    DRIVER_NAME = 'com.ibm.db2.jcc.DB2Driver'.freeze

    # @private
    def zos?
      @zos = nil unless defined? @zos
      return @zos unless @zos.nil?
      @zos =
        if url = config[:url]
          !!( url =~ /^jdbc:db2j:net:/ && config[:driver] == DRIVER_NAME )
        else
          nil
        end
    end

    # @private
    # @deprecated no longer used
    def as400?
      false
    end

    def schema
      db2_schema
    end

    def schema=(schema)
      set_schema(@db2_schema = schema) if db2_schema != schema
    end

    private

    def set_schema(schema)
      execute("SET SCHEMA #{schema}")
    end

    def db2_schema
      @db2_schema = false unless defined? @db2_schema
      return @db2_schema if @db2_schema != false
      schema = config[:schema]
      @db2_schema =
        if schema then schema
        elsif config[:jndi] || config[:data_source]
          nil # let JNDI worry about schema
        else
          # LUW implementation uses schema name of username by default
          config[:username] || ENV['USER']
        end
    end

    def db2_remove_column(table_name, column_name)
      sql = "ALTER TABLE #{quote_table_name(table_name)} DROP COLUMN #{quote_column_name(column_name)}"
      execute_table_change(sql, table_name, 'Remove Column')
    end

  end
end

module ActiveRecord::ConnectionAdapters

  remove_const(:DB2Column) if const_defined?(:DB2Column)

  class DB2Column < JdbcColumn
    include ::ArJdbc::DB2::Column
  end

end
