module ArJdbc
  module DB2
    def self.extended(base)
      if base.send(:zos?)
        unless @_lob_callback_added
          ActiveRecord::Base.class_eval do
            def after_save_with_db2zos_blob
              lobfields = self.class.columns.select { |c| c.sql_type =~ /blob|clob/i }
              lobfields.each do |c|
                value = self[c.name]
                if respond_to?(:unserializable_attribute?)
                  value = value.to_yaml if unserializable_attribute?(c.name, c)
                else
                  value = value.to_yaml if value.is_a?(Hash)
                end
                next if value.nil?
                connection.write_large_object(c.type == :binary, c.name, self.class.table_name, self.class.primary_key, quote_value(id), value)
              end
            end
          end
          ActiveRecord::Base.after_save :after_save_with_db2zos_blob
          @_lob_callback_added = true
        end
      end
    end

    def self.column_selector
      [ /(db2|as400|zos)/i, lambda { |cfg, column| column.extend(::ArJdbc::DB2::Column) } ]
    end

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::DB2JdbcConnection
    end

    NATIVE_DATABASE_TYPES = {
      :double    => { :name => "double" },
      :bigint    => { :name => "bigint" }
    }

    def native_database_types
      super.merge(NATIVE_DATABASE_TYPES)
    end

    def prefetch_primary_key?(table_name = nil)
      # TRUE if the table has no identity column
      names = table_name.upcase.split(".")
      sql = "SELECT 1 FROM SYSCAT.COLUMNS WHERE IDENTITY = 'Y' "
      sql += "AND TABSCHEMA = '#{names.first}' " if names.size == 2
      sql += "AND TABNAME = '#{names.last}'"
      select_one(sql).nil?
    end

    def next_sequence_value(sequence_name)
      select_value("select next value for #{sequence_name} from sysibm.sysdummy1")
    end

    module Column
      def type_cast(value)
        return nil if value.nil? || value =~ /^\s*null\s*$/i
        case type
        when :string    then value
        when :integer   then defined?(value.to_i) ? value.to_i : (value ? 1 : 0)
        when :primary_key then defined?(value.to_i) ? value.to_i : (value ? 1 : 0)
        when :float     then value.to_f
        when :datetime  then ArJdbc::DB2::Column.cast_to_date_or_time(value)
        when :date      then ArJdbc::DB2::Column.cast_to_date_or_time(value)
        when :timestamp then ArJdbc::DB2::Column.cast_to_time(value)
        when :time      then ArJdbc::DB2::Column.cast_to_time(value)
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
        when /^decimal\(1\)$/i  then :boolean
        when /^real/i           then :float
        when /^timestamp/i      then :datetime
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

    def _execute(sql, name = nil)
      if self.class.select?(sql)
        @connection.execute_query(sql)
      elsif self.class.insert?(sql)
        (@connection.execute_insert(sql) or last_insert_id(sql)).to_i
      else
        @connection.execute_update(sql)
      end
    end

    # holy moly batman! all this to tell AS400 "yes i am sure"
    def execute_and_auto_confirm(sql)
      begin
        @connection.execute_update "call qsys.qcmdexc('QSYS/CHGJOB INQMSGRPY(*SYSRPYL)',0000000031.00000)"
        @connection.execute_update "call qsys.qcmdexc('ADDRPYLE SEQNBR(9876) MSGID(CPA32B2) RPY(''I'')',0000000045.00000)"
      rescue Exception => e
        raise "Could not call CHGJOB INQMSGRPY(*SYSRPYL) and ADDRPYLE SEQNBR(9876) MSGID(CPA32B2) RPY('I').\n" +
          "Do you have authority to do this?\n\n" + e.to_s
      end

      r = execute sql

      begin
        @connection.execute_update "call qsys.qcmdexc('QSYS/CHGJOB INQMSGRPY(*DFT)',0000000027.00000)"
        @connection.execute_update "call qsys.qcmdexc('RMVRPYLE SEQNBR(9876)',0000000021.00000)"
      rescue Exception => e
        raise "Could not call CHGJOB INQMSGRPY(*DFT) and RMVRPYLE SEQNBR(9876).\n" +
          "Do you have authority to do this?\n\n" + e.to_s
      end
      r
    end

    def last_insert_id(sql)
      table_name = sql.split(/\s/)[2]
      result = select(ActiveRecord::Base.send(:sanitize_sql, %[select IDENTITY_VAL_LOCAL() as last_insert_id from #{table_name}], nil))
      result.last['last_insert_id']
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

    def adapter_name
      'DB2'
    end

    def self.arel2_visitors(config)
      require 'arel/visitors/db2'
      {}.tap {|v| %w(db2 as400).each {|a| v[a] = ::Arel::Visitors::DB2 } }
    end

    def add_limit_offset!(sql, options)
      replace_limit_offset!(sql, options[:limit], options[:offset])
    end


    def create_table(name, options = {}) #:nodoc:
      if zos?
        table_definition = ActiveRecord::ConnectionAdapters::TableDefinition.new(self)

        table_definition.primary_key(options[:primary_key] || ActiveRecord::Base.get_primary_key(name)) unless options[:id] == false

        yield table_definition

        # Clobs in DB2 Host have to be created after the Table with an auxiliary Table.
        # First: Save them for later in Array "clobs"
        clobs = table_definition.columns.select { |x| x.type == "text" }
        # Second: and delete them from the original Colums-Array
        table_definition.columns.delete_if { |x| x.type == "text" }

        if options[:force] && table_exists?(name)
          super.drop_table(name, options)
        end

        create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
        create_sql << "#{quote_table_name(name)} ("
        create_sql << table_definition.to_sql
        create_sql << ") #{options[:options]}"
        create_sql << " IN #{@config[:database]}.#{@config[:tablespace]}" if @config[:database] && @config[:tablespace]

        execute create_sql

        clobs.each do |clob_column|
          execute "ALTER TABLE #{name+" ADD COLUMN "+clob_column.name.to_s+" clob"}"
          execute "CREATE AUXILIARY TABLE #{name+"_"+clob_column.name.to_s+"_CD_"} IN #{@config[:database]}.#{@config[:lob_tablespaces][name.split(".")[1]]} STORES #{name} COLUMN "+clob_column.name.to_s
          execute "CREATE UNIQUE INDEX #{name+"_"+clob_column.name.to_s+"_CD_"} ON #{name+"_"+clob_column.name.to_s+"_CD_"};"
        end
      else
        super(name, options)
      end
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
          offset = offset.to_i
          sql.sub!(/SELECT/i, 'SELECT B.* FROM (SELECT A.*, row_number() over () AS internal$rownum FROM (SELECT')
          sql << ") A ) B WHERE B.internal$rownum > #{offset} AND B.internal$rownum <= #{limit + offset}"
        end
      end
      sql
    end

    def pk_and_sequence_for(table)
      # In JDBC/DB2 side, only upcase names of table and column are handled.
      keys = super(table.upcase)
      if keys && keys[0]
        # In ActiveRecord side, only downcase names of table and column are handled.
        keys[0] = keys[0].downcase
      end
      keys
    end

    def quote_column_name(column_name)
      column_name.to_s
    end

    def quote(value, column = nil) # :nodoc:
      if column && column.respond_to?(:primary) && column.primary && column.klass != String
        return value.to_i.to_s
      end
      if column && (column.type == :decimal || column.type == :integer) && value
        return value.to_s
      end
      case value
      when String
        if column && column.type == :binary
          "BLOB('#{quote_string(value)}')"
        else
          if zos? && column && column.type == :text
            "'if_you_see_this_value_the_after_save_hook_in_db2_zos_adapter_went_wrong'"
          else
            "'#{quote_string(value)}'"
          end
        end
      else super
      end
    end

    def quote_string(string)
      string.gsub(/'/, "''") # ' (for ruby-mode)
    end

    def quoted_true
      '1'
    end

    def quoted_false
      '0'
    end

    def reorg_table(table_name)
      unless as400?
        @connection.execute_update "call sysproc.admin_cmd ('REORG TABLE #{table_name}')"
      end
    end

    def runstats_for_table(tablename, priority=10)
      @connection.execute_update "call sysproc.admin_cmd('RUNSTATS ON TABLE #{tablename} WITH DISTRIBUTION AND DETAILED INDEXES ALL UTIL_IMPACT_PRIORITY #{priority}')"
    end

    def recreate_database(name, options = {})
      tables.each {|table| drop_table("#{db2_schema}.#{table}")}
    end

    def add_index(table_name, column_name, options = {})
      if (!zos? || (table_name.to_s ==  ActiveRecord::Migrator.schema_migrations_table_name.to_s))
        column_name = column_name.to_s if column_name.is_a?(Symbol)
        super
      else
        statement ="CREATE"
        statement << " UNIQUE " if options[:unique]
        statement << " INDEX "+"#{ActiveRecord::Base.table_name_prefix}#{options[:name]} "

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
      if as400?
        raise NotImplementedError, "rename_column is not supported on IBM i"
      else
        execute "ALTER TABLE #{table_name} RENAME COLUMN #{column_name} TO #{new_column_name}"
        reorg_table(table_name)
      end
    end

    def change_column_null(table_name, column_name, null)
      if null
        sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} DROP NOT NULL"
      else
        sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET NOT NULL"
      end
      as400? ? execute_and_auto_confirm(sql) : execute(sql)
      reorg_table(table_name)
    end

    def change_column_default(table_name, column_name, default)
      if default.nil?
        sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} DROP DEFAULT"
      else
        sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET WITH DEFAULT #{quote(default)}"
      end
      as400? ? execute_and_auto_confirm(sql) : execute(sql)
      reorg_table(table_name)
    end

    def change_column(table_name, column_name, type, options = {})
      data_type = type_to_sql(type, options[:limit], options[:precision], options[:scale])
      sql = "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET DATA TYPE #{data_type}"
      as400? ? execute_and_auto_confirm(sql) : execute(sql)
      reorg_table(table_name)

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
    def remove_column(table_name, column_name) #:nodoc:
      sql = "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"

      as400? ? execute_and_auto_confirm(sql) : execute(sql)
      reorg_table(table_name)
    end

    # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000980.html
    def rename_table(name, new_name) #:nodoc:
      execute "RENAME TABLE #{name} TO #{new_name}"
      reorg_table(new_name)
    end

    def tables
      @connection.tables(nil, db2_schema, nil, ["TABLE"])
    end

    # only record precision and scale for types that can set them via CREATE TABLE:
    # http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000927.html
    HAVE_LIMIT = %w(FLOAT DECFLOAT CHAR VARCHAR CLOB BLOB NCHAR NCLOB DBCLOB GRAPHIC VARGRAPHIC) #TIMESTAMP
    HAVE_PRECISION = %w(DECIMAL NUMERIC)
    HAVE_SCALE = %w(DECIMAL NUMERIC)

    def columns(table_name, name = nil)
      cols = @connection.columns(table_name, name, db2_schema)

      if zos?
        # Remove the mighty db2_generated_rowid_for_lobs from the list of columns
        cols = cols.reject { |col| "db2_generated_rowid_for_lobs" == col.name }
      end
      # scrub out sizing info when CREATE TABLE doesn't support it
      # but JDBC reports it (doh!)
      for col in cols
        base_sql_type = col.sql_type.sub(/\(.*/, "").upcase
        col.limit = nil unless HAVE_LIMIT.include?(base_sql_type)
        col.precision = nil unless HAVE_PRECISION.include?(base_sql_type)
        #col.scale = nil unless HAVE_SCALE.include?(base_sql_type)
      end

      cols
    end

    def jdbc_columns(table_name, name = nil)
      columns(table_name, name)
    end

    def indexes(table_name, name = nil)
      @connection.indexes(table_name, name, db2_schema)
    end

    def add_quotes(name)
      return name unless name
      %Q{"#{name}"}
    end

    def strip_quotes(str)
      return str unless str
      return str unless /^(["']).*\1$/ =~ str
      str[1..-2]
    end

    def expand_double_quotes(name)
      return name unless name && name['"']
      name.gsub(/"/,'""')
    end

    def structure_dump #:nodoc:
      schema_name = db2_schema.upcase if db2_schema.present?
      rs = @connection.connection.meta_data.getTables(nil, schema_name, nil, ["TABLE"].to_java(:string))
      definition = ''
      while rs.next
        tname = rs.getString(3)
        definition << "CREATE TABLE #{tname} (\n"
        rs2 = @connection.connection.meta_data.getColumns(nil,schema_name,tname,nil)
        first_col = true
        while rs2.next
          col_name = add_quotes(rs2.getString(4));
          default = ""
          d1 = rs2.getString(13)
          # IBM i (as400 toolbox driver) will return an empty string if there is no default
          if @config[:url] =~ /^jdbc:as400:/
            default = !d1.blank? ? " DEFAULT #{d1}" : ""
          else
            default = d1 ? " DEFAULT #{d1}" : ""
          end

          type = rs2.getString(6)
          col_precision = rs2.getString(7)
          col_scale = rs2.getString(9)
          col_size = ""
          if HAVE_SCALE.include?(type) and col_scale
            col_size = "(#{col_precision},#{col_scale})"
          elsif (HAVE_LIMIT + HAVE_PRECISION).include?(type) and col_precision
            col_size = "(#{col_precision})"
          end
          nulling = (rs2.getString(18) == 'NO' ? " NOT NULL" : "")
          autoincrement = (rs2.getString(23) == 'YES' ? " GENERATED ALWAYS AS IDENTITY" : "")
          create_col_string = add_quotes(expand_double_quotes(strip_quotes(col_name))) +
            " " +
            type +
            col_size +
            "" +
            nulling +
            default +
            autoincrement
          if !first_col
            create_col_string = ",\n #{create_col_string}"
          else
            create_col_string = " #{create_col_string}"
          end

          definition << create_col_string

          first_col = false
        end
        definition << ");\n\n"

        pkrs = @connection.connection.meta_data.getPrimaryKeys(nil,schema_name,tname)
        primary_key = {}
        while pkrs.next
          name = pkrs.getString(6)
          primary_key[name] = [] unless primary_key[name]
          primary_key[name] << pkrs.getString(4)
        end
        primary_key.each do |name, cols|
          definition << "ALTER TABLE #{tname}\n"
          definition << "  ADD CONSTRAINT #{name}\n"
          definition << "      PRIMARY KEY (#{cols.join(', ')});\n\n"
        end
      end
      definition
    end
    
    DRIVER_NAME = 'com.ibm.db2.jcc.DB2Driver'.freeze
    
    def zos?
      return @zos unless @zos.nil?
      @zos = 
        if url = @config[:url]
          !!( url =~ /^jdbc:db2j:net:/ && @config[:driver] == DRIVER_NAME )
        else
          nil
        end
    end
    
    def as400?
      return @as400 unless @as400.nil?
      @as400 = 
        if url = @config[:url]
          !!( url =~ /^jdbc:as400:/ )
        else
          nil
        end
    end

    private
    
    def db2_schema
      return @db2_schema unless @db2_schema.nil?
      @db2_schema = 
        if @config[:schema].present?
          @config[:schema]
        elsif @config[:jndi].present?
          nil # let JNDI worry about schema
        elsif as400?
          # AS400 implementation takes schema from library name (last part of URL)
          # jdbc:as400://localhost/schema;naming=system;libraries=lib1,lib2
          @config[:url].split('/').last.split(';').first.strip
        else
          # LUW implementation uses schema name of username by default
          @config[:username].presence || ENV['USER']
        end
    end
    
  end
end
