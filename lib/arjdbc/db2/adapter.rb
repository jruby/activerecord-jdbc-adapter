ArJdbc.load_java_part :DB2

module ArJdbc
  module DB2

    # This adapter doesn't support explain
    # config.active_record.auto_explain_threshold_in_seconds should be commented before rails 4.0
    
    def self.extended(adapter); initialize!; end
    
    @@_initialized = nil
    
    def self.initialize!
      return if @@_initialized; @@_initialized = true
      
      require 'arjdbc/jdbc/serialized_attributes_helper'
      ActiveRecord::Base.class_eval do
        def after_save_with_db2_lob
          lob_columns = self.class.columns.select { |c| c.sql_type =~ /blob|clob/i }
          lob_columns.each do |column|
            value = ::ArJdbc::SerializedAttributesHelper.dump_column_value(self, column)
            next if value.nil? # already set NULL

            self.class.connection.write_large_object(
              column.type == :binary, column.name, 
              self.class.table_name, 
              self.class.primary_key, 
              self.class.connection.quote(id), value
            )
          end
        end
      end
      ActiveRecord::Base.after_save :after_save_with_db2_lob
    end
    
    def self.column_selector
      [ /(db2|zos)/i, lambda { |cfg, column| column.extend(::ArJdbc::DB2::Column) } ]
    end

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::DB2JdbcConnection
    end

    def self.arel2_visitors(config)
      require 'arel/visitors/db2'
      { 'db2' => ::Arel::Visitors::DB2 }
    end
    
    def self.handle_lobs?; true; end
    
    def configure_connection
      schema = self.schema
      set_schema(schema) if schema && schema != config[:username]
    end
    
    ADAPTER_NAME = 'DB2'.freeze
    
    def adapter_name
      ADAPTER_NAME
    end
    
    NATIVE_DATABASE_TYPES = {
      :double     => { :name => "double" },
      :bigint     => { :name => "bigint" },
      :string     => { :name => "varchar", :limit => 255 },
      :text       => { :name => "clob" },
      :date       => { :name => "date" },
      :binary     => { :name => "blob" },
      :boolean    => { :name => "smallint" }, # no native boolean type
      :xml        => { :name => "xml" },
      :decimal    => { :name => "decimal" },
      :char       => { :name => "char" },
      :decfloat   => { :name => "decfloat" },
      :rowid      => { :name => "rowid" }, # rowid is a supported datatype on z/OS and i/5
      :serial     => { :name => "serial" }, # supported datatype on Informix Dynamic Server
      :graphic    => { :name => "graphic", :limit => 1 },
      :vargraphic => { :name => "vargraphic", :limit => 1 },
      :datetime   => { :name => "timestamp" },
      :timestamp  => { :name => "timestamp" },
      :time       => { :name => "time" }
    }

    def native_database_types
      super.merge(NATIVE_DATABASE_TYPES)
    end

    @@emulate_booleans = true
    
    # Boolean emulation can be disabled using :
    # 
    #   ArJdbc::DB2.emulate_booleans = false
    # 
    def self.emulate_booleans; @@emulate_booleans; end
    def self.emulate_booleans=(emulate); @@emulate_booleans = emulate; end
    
    module Column
      
      def type_cast(value)
        return nil if value.nil? || value == 'NULL' || value =~ /^\s*NULL\s*$/i
        case type
        when :string    then value
        when :integer   then value.respond_to?(:to_i) ? value.to_i : (value ? 1 : 0)
        when :primary_key then value.respond_to?(:to_i) ? value.to_i : (value ? 1 : 0)
        when :float     then value.to_f
        when :datetime  then Column.cast_to_date_or_time(value)
        when :date      then Column.cast_to_date_or_time(value)
        when :timestamp then Column.cast_to_time(value)
        when :time      then Column.cast_to_time(value)
        # TODO AS400 stores binary strings in EBCDIC (CCSID 65535), need to convert back to ASCII
        else
          super
        end
      end

      def type_cast_code(var_name)
        case type
        when :datetime  then "ArJdbc::DB2::Column.cast_to_date_or_time(#{var_name})"
        when :date      then "ArJdbc::DB2::Column.cast_to_date_or_time(#{var_name})"
        when :timestamp then "ArJdbc::DB2::Column.cast_to_time(#{var_name})"
        when :time      then "ArJdbc::DB2::Column.cast_to_time(#{var_name})"
        else
          super
        end
      end

      def self.cast_to_date_or_time(value)
        return value if value.is_a? Date
        return nil if value.blank?
        # https://github.com/jruby/activerecord-jdbc-adapter/commit/c225126e025df2e98ba3386c67e2a5bc5e5a73e6
        return Time.now if value =~ /^CURRENT/
        guess_date_or_time((value.is_a? Time) ? value : cast_to_time(value))
      rescue
        value
      end

      def self.cast_to_time(value)
        return value if value.is_a? Time
        # AS400 returns a 2 digit year, LUW returns a 4 digit year, so comp = true to help out AS400
        time = DateTime.parse(value).to_time rescue nil
        return nil unless time
        time_array = [time.year, time.month, time.day, time.hour, time.min, time.sec]
        time_array[0] ||= 2000; time_array[1] ||= 1; time_array[2] ||= 1;
        Time.send(ActiveRecord::Base.default_timezone, *time_array) rescue nil
      end

      def self.guess_date_or_time(value)
        return value if value.is_a? Date
        ( value && value.hour == 0 && value.min == 0 && value.sec == 0 ) ? 
          Date.new(value.year, value.month, value.day) : value
      end

      private
      # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.apdv.java.doc/doc/rjvjdata.html
      def simplified_type(field_type)
        case field_type
        when /^decimal\(1\)$/i   then DB2.emulate_booleans ? :boolean : :integer
        when /smallint/i         then DB2.emulate_booleans ? :boolean : :integer
        when /boolean/i          then :boolean
        when /^real|double/i     then :float
        when /int|serial/i       then :integer
        # if a numeric column has no scale, lets treat it as an integer.
        # The AS400 rpg guys do this ALOT since they have no integer datatype ...
        when /decimal|numeric|decfloat/i
          extract_scale(field_type) == 0 ? :integer : :decimal
        when /timestamp/i        then :timestamp
        when /datetime/i         then :datetime
        when /time/i             then :time
        when /date/i             then :date
        when /clob|text/i        then :text
        when /blob|binary/i      then :binary
        when /for bit data/i     then :binary
        when /xml/i              then :xml
        when /^vargraphic/i      then :vargraphic
        when /^graphic/i         then :graphic
        when /rowid/i            then :rowid # rowid is a supported datatype on z/OS and i/5
        else
          super
        end
      end

      # Post process default value from JDBC into a Rails-friendly format (columns{-internal})
      def default_value(value)
        # IBM i (AS400) will return an empty string instead of null for no default
        return nil if value.blank?

        # string defaults are surrounded by single quotes
        return $1 if value =~ /^'(.*)'$/

        value
      end
    end

    class TableDefinition < ::ActiveRecord::ConnectionAdapters::TableDefinition # :nodoc:
      
      def xml(*args)
        options = args.extract_options!
        column(args[0], 'xml', options)
      end
      
      # IBM DB adapter (MRI) compatibility :
      
      def double(*args)
        options = args.extract_options!
        column(args[0], 'double', options)
      end

      def decfloat(*args)
        options = args.extract_options!
        column(args[0], 'decfloat', options)
      end

      def graphic(*args)
        options = args.extract_options!
        column(args[0], 'graphic', options)
      end

      def vargraphic(*args)
        options = args.extract_options!
        column(args[0], 'vargraphic', options)
      end

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
    
    def last_insert_id(sql)
      table_name = sql.split(/\s/)[2]
      result = select(ActiveRecord::Base.send(:sanitize_sql, %[SELECT IDENTITY_VAL_LOCAL() AS last_insert_id FROM #{table_name}], nil))
      result.last['last_insert_id']
    end
    
    def create_table(name, options = {}) #:nodoc:
      if zos?
        zos_create_table(name, options)
      else
        super(name, options)
      end
    end
    
    def zos_create_table(name, options = {}) # :nodoc:
      # NOTE: this won't work for 4.0 - need to pass different initialize args :
      table_definition = TableDefinition.new(self)
      unless options[:id] == false
        table_definition.primary_key(options[:primary_key] || primary_key(name))
      end

      yield table_definition

      # Clobs in DB2 Host have to be created after the Table with an auxiliary Table.
      # First: Save them for later in Array "clobs"
      clobs = table_definition.columns.select { |x| x.type.to_s == "text" }
      # Second: and delete them from the original Colums-Array
      table_definition.columns.delete_if { |x| x.type.to_s == "text" }

      drop_table(name, options) if options[:force] && table_exists?(name)

      create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
      create_sql << "#{quote_table_name(name)} ("
      create_sql << table_definition.to_sql
      create_sql << ") #{options[:options]}"
      if @config[:database] && @config[:tablespace]
        in_db_table_space = " IN #{@config[:database]}.#{@config[:tablespace]}"
      else
        in_db_table_space = ''
      end
      create_sql << in_db_table_space

      execute create_sql

      # Table definition is complete only when a unique index is created on the primary_key column for DB2 V8 on zOS
      # create index on id column if options[:id] is nil or id ==true
      # else check if options[:primary_key]is not nil then create an unique index on that column
      # TODO someone on Z/OS should test this out - also not needed for V9 ?
      #primary_column = options[:id] == true ? 'id' : options[:primary_key]
      #add_index(name, (primary_column || 'id').to_s, :unique => true)

      clobs.each do |clob_column|
        column_name = clob_column.name.to_s
        execute "ALTER TABLE #{name + ' ADD COLUMN ' + column_name + ' clob'}"
        clob_table_name = name + '_' + column_name + '_CD_'
        if @config[:database] && @config[:lob_tablespaces]
          in_lob_table_space = " IN #{@config[:database]}.#{@config[:lob_tablespaces][name.split(".")[1]]}"
        else
          in_lob_table_space = ''
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
    # +value+ contains the data, +column+ is optional and contains info on the field
    def quote(value, column = nil) # :nodoc:
      return value.quoted_id if value.respond_to?(:quoted_id)
      
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
      when nil then "NULL"
      when Numeric # IBM_DB doesn't accept quotes on numeric types
        # if the column type is text or string, return the quote value
        if column_type == :text || column_type == :string
          "'#{value}'"
        else
          value.to_s
        end
      when String, ActiveSupport::Multibyte::Chars
        if column_type == :binary && !(column.sql_type =~ /for bit data/i)
          if ArJdbc::DB2.handle_lobs?
            "NULL" # '@@@IBMBINARY@@@'"
          else
            "BLOB('#{quote_string(value)}')"
          end
        elsif column && column.sql_type =~ /clob/ # :text
          if ArJdbc::DB2.handle_lobs?
            "NULL" # "'@@@IBMTEXT@@@'"
          else
            "'#{quote_string(value)}'"
          end
        elsif column_type == :xml
          value.nil? ? "NULL" : "'#{quote_string(value)}'" # "'<ibm>@@@IBMXML@@@</ibm>'"
        else
          "'#{quote_string(value)}'"
        end
      when Symbol then "'#{quote_string(value.to_s)}'"
      when Time
        # AS400 doesn't support date in time column
        if column && column_type == :time
          "'#{value.strftime("%H:%M:%S")}'"
        else
          super
        end
      else super
      end
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

    def add_limit_offset!(sql, options)
      replace_limit_offset!(sql, options[:limit], options[:offset])
    end
    
    def add_column_options!(sql, options) # :nodoc:
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
   
    def replace_limit_offset!(sql, limit, offset)
      if limit
        limit = limit.to_i

        if !offset
          if limit == 1
            sql << " FETCH FIRST ROW ONLY"
          else
            sql << " FETCH FIRST #{limit} ROWS ONLY"
          end
        else
          replace_limit_offset_with_ordering( sql, limit, offset )
        end
        
      end
      sql
    end

    def replace_limit_offset_for_arel!( query, sql )
      replace_limit_offset_with_ordering sql, query.limit.value, query.offset && query.offset.value, query.orders
    end

    def replace_limit_offset_with_ordering( sql, limit, offset, orders=[] )
      sql.sub!(/SELECT/i, "SELECT B.* FROM (SELECT A.*, row_number() over (#{build_ordering(orders)}) AS internal$rownum FROM (SELECT")
      sql << ") A ) B WHERE B.internal$rownum > #{offset} AND B.internal$rownum <= #{limit + offset}"
      sql
    end
    private :replace_limit_offset_with_ordering
    
    def build_ordering( orders )
      return '' unless orders.size > 0
      # need to remove the library/table names from the orderings because we are not really ordering by them anymore
      # we are actually ordering by the results of a query where the result set has the same column names
      orders = orders.map do |o| 
        # need to keep in mind that the order clause could be wrapped in a function
        matches = /(?:\w+\(|\s)*(\S+)(?:\)|\s)*/.match(o)
        o = o.gsub( matches[1], matches[1].split('.').last ) if matches
        o
      end
      "ORDER BY " + orders.join( ', ')
    end
    private :build_ordering

    # @deprecated seems not sued nor tested ?!
    def runstats_for_table(tablename, priority = 10)
      @connection.execute_update "call sysproc.admin_cmd('RUNSTATS ON TABLE #{tablename} WITH DISTRIBUTION AND DETAILED INDEXES ALL UTIL_IMPACT_PRIORITY #{priority}')"
    end

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

    def remove_index(table_name, options = { })
      execute "DROP INDEX #{quote_column_name(index_name(table_name, options))}"
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
    
    # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.admin.dbobj.doc/doc/t0020132.html
    def remove_column(table_name, *column_names) # :nodoc:
      outcome = nil
      column_names = column_names.flatten
      for column_name in column_names
        sql = "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"
        outcome = execute_table_change(sql, table_name, 'Remove Column')
      end
      column_names.size == 1 ? outcome : nil
    end

    # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000980.html
    def rename_table(name, new_name) # :nodoc:
      execute_table_change("RENAME TABLE #{name} TO #{new_name}", new_name, 'Rename Table')
    end
    
    def tables
      @connection.tables(nil, schema)
    end

    # only record precision and scale for types that can set them via CREATE TABLE:
    # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000927.html
    HAVE_LIMIT = %w(FLOAT DECFLOAT CHAR VARCHAR CLOB BLOB NCHAR NCLOB DBCLOB GRAPHIC VARGRAPHIC) #TIMESTAMP
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

    def _execute(sql, name = nil)
      if self.class.select?(sql)
        @connection.execute_query_raw(sql)
      elsif self.class.insert?(sql)
        (@connection.execute_insert(sql) || last_insert_id(sql)).to_i
      else
        @connection.execute_update(sql)
      end
    end
    private :_execute
    
    DRIVER_NAME = 'com.ibm.db2.jcc.DB2Driver'.freeze
    
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
      @db2_schema = 
        if config[:schema].present?
          config[:schema]
        elsif config[:jndi].present?
          nil # let JNDI worry about schema
        else
          # LUW implementation uses schema name of username by default
          config[:username].presence || ENV['USER']
        end
    end
    
  end
end
