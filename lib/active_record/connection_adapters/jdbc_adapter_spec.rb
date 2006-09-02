
module JdbcSpec
  module OracleSequenceSupport
    def default_sequence_name(table, column) #:nodoc:
      "#{table}_seq"
    end
    
    def create_table(name, options = {}) #:nodoc:
      super(name, options)
      execute "CREATE SEQUENCE #{name}_seq START WITH 10000" unless options[:id] == false
    end

    def rename_table(name, new_name) #:nodoc:
      execute "RENAME #{name} TO #{new_name}"
      execute "RENAME #{name}_seq TO #{new_name}_seq" rescue nil
    end  

    def drop_table(name) #:nodoc:
      super(name)
      execute "DROP SEQUENCE #{name}_seq" rescue nil
    end

    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
      if pk.nil? # Who called us? What does the sql look like? No idea!
        execute sql, name
      elsif id_value # Pre-assigned id
        log(sql, name) { @connection.execute_insert sql,pk }
      else # Assume the sql contains a bind-variable for the id
        id_value = select_one("select #{sequence_name}.nextval id from dual")['id']
        log(sql, name) { 
          execute_prepared_insert(sql,id_value)
        }
      end
      id_value
    end
    
    def execute_prepared_insert(sql, id)
      @stmts ||= {}
      @stmts[sql] ||= @connection.ps(sql)
      stmt = @stmts[sql]
      stmt.setLong(1,id)
      stmt.executeUpdate
      id
    end
  end
  
  module Oracle
    include OracleSequenceSupport 
    
    def modify_types(tp)
      tp[:primary_key] = "NUMBER(38) NOT NULL PRIMARY KEY"
      tp
    end

    def add_limit_offset!(sql, options) #:nodoc:
      offset = options[:offset] || 0
      
      if limit = options[:limit]
        sql.replace "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_ where rownum <= #{offset+limit}) where raw_rnum_ > #{offset}"
      elsif offset > 0
        sql.replace "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_) where raw_rnum_ > #{offset}"
      end
    end

    def current_database #:nodoc:
      select_one("select sys_context('userenv','db_name') db from dual")["db"]
    end

    def indexes(table_name, name = nil) #:nodoc:
      result = select_all(<<-SQL, name)
      SELECT lower(i.index_name) as index_name, i.uniqueness, lower(c.column_name) as column_name
      FROM user_indexes i, user_ind_columns c
      WHERE i.table_name = '#{table_name.to_s.upcase}'
      AND c.index_name = i.index_name
      AND i.index_name NOT IN (SELECT index_name FROM user_constraints WHERE constraint_type = 'P')
      ORDER BY i.index_name, c.column_position
      SQL

      current_index = nil
      indexes = []

      result.each do |row|
        if current_index != row['index_name']
          indexes << IndexDefinition.new(table_name, row['index_name'], row['uniqueness'] == "UNIQUE", [])
          current_index = row['index_name']
        end

        indexes.last.columns << row['column_name']
      end

      indexes
    end

    def remove_index(table_name, options = {}) #:nodoc:
      execute "DROP INDEX #{index_name(table_name, options)}"
    end

    def change_column_default(table_name, column_name, default) #:nodoc:
      execute "ALTER TABLE #{table_name} MODIFY #{column_name} DEFAULT #{quote(default)}"
    end

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      change_column_sql = "ALTER TABLE #{table_name} MODIFY #{column_name} #{type_to_sql(type, options[:limit])}"
      add_column_options!(change_column_sql, options)
      execute(change_column_sql)
    end

    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      execute "ALTER TABLE #{table_name} RENAME COLUMN #{column_name} to #{new_column_name}"
    end

    def remove_column(table_name, column_name) #:nodoc:
      execute "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"
    end

    def structure_dump #:nodoc:
      s = select_all("select sequence_name from user_sequences").inject("") do |structure, seq|
        structure << "create sequence #{seq.to_a.first.last};\n\n"
      end

      select_all("select table_name from user_tables").inject(s) do |structure, table|
        ddl = "create table #{table.to_a.first.last} (\n "  
        cols = select_all(%Q{
              select column_name, data_type, data_length, data_precision, data_scale, data_default, nullable
              from user_tab_columns
              where table_name = '#{table.to_a.first.last}'
              order by column_id
            }).map do |row|              
          col = "#{row['column_name'].downcase} #{row['data_type'].downcase}"      
          if row['data_type'] =='NUMBER' and !row['data_precision'].nil?
            col << "(#{row['data_precision'].to_i}"
            col << ",#{row['data_scale'].to_i}" if !row['data_scale'].nil?
            col << ')'
          elsif row['data_type'].include?('CHAR')
            col << "(#{row['data_length'].to_i})"  
          end
          col << " default #{row['data_default']}" if !row['data_default'].nil?
          col << ' not null' if row['nullable'] == 'N'
          col
        end
        ddl << cols.join(",\n ")
        ddl << ");\n\n"
        structure << ddl
      end
    end

    def structure_drop #:nodoc:
      s = select_all("select sequence_name from user_sequences").inject("") do |drop, seq|
        drop << "drop sequence #{seq.to_a.first.last};\n\n"
      end

      select_all("select table_name from user_tables").inject(s) do |drop, table|
        drop << "drop table #{table.to_a.first.last} cascade constraints;\n\n"
      end
    end
  end

  module PostgreSQL
    def modify_types(tp)
      tp[:primary_key] = "serial primary key"
      tp[:string][:limit] = 255
      tp
    end
    
    def default_sequence_name(table_name, pk = nil)
      default_pk, default_seq = pk_and_sequence_for(table_name)
      default_seq || "#{table_name}_#{pk || default_pk || 'id'}_seq"
    end

    # Find a table's primary key and sequence.
    def pk_and_sequence_for(table)
      # First try looking for a sequence with a dependency on the
        # given table's primary key.
        result = execute(<<-end_sql, 'PK and serial sequence')[0]
          SELECT attr.attname, name.nspname, seq.relname
          FROM pg_class      seq,
               pg_attribute  attr,
               pg_depend     dep,
               pg_namespace  name,
               pg_constraint cons
          WHERE seq.oid           = dep.objid
            AND seq.relnamespace  = name.oid
            AND seq.relkind       = 'S'
            AND attr.attrelid     = dep.refobjid
            AND attr.attnum       = dep.refobjsubid
            AND attr.attrelid     = cons.conrelid
            AND attr.attnum       = cons.conkey[1]
            AND cons.contype      = 'p'
            AND dep.refobjid      = '#{table}'::regclass
        end_sql

        if result.nil? or result.empty?
          # If that fails, try parsing the primary key's default value.
          # Support the 7.x and 8.0 nextval('foo'::text) as well as
          # the 8.1+ nextval('foo'::regclass).
          # TODO: assumes sequence is in same schema as table.
          result = execute(<<-end_sql, 'PK and custom sequence')[0]
            SELECT attr.attname, name.nspname, split_part(def.adsrc, '\\\'', 2)
            FROM pg_class       t
            JOIN pg_namespace   name ON (t.relnamespace = name.oid)
            JOIN pg_attribute   attr ON (t.oid = attrelid)
            JOIN pg_attrdef     def  ON (adrelid = attrelid AND adnum = attnum)
            JOIN pg_constraint  cons ON (conrelid = adrelid AND adnum = conkey[1])
            WHERE t.oid = '#{table}'::regclass
              AND cons.contype = 'p'
              AND def.adsrc ~* 'nextval'
          end_sql
        end
        # check for existence of . in sequence name as in public.foo_sequence.  if it does not exist, join the current namespace
        result.last['.'] ? [result.first, result.last] : [result.first, "#{result[1]}.#{result[2]}"]
      rescue
        nil
      end

    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
      execute(sql, name)
      table = sql.split(" ", 4)[2]
      id_value || last_insert_id(table, sequence_name || default_sequence_name(table, pk))
    end

    def last_insert_id(table, sequence_name)
      Integer(select_value("SELECT currval('#{sequence_name}')"))
    end
  end  
  
  module MySQL
    def modify_types(tp)
      tp[:primary_key] = "int(11) DEFAULT NULL auto_increment PRIMARY KEY"
      tp[:decimal] = { :name => "datetime" }
      tp
    end
    
    # QUOTING ==================================================
    
    def quote(value, column = nil)
        super
    end
    
    def quote_column_name(name) #:nodoc:
        "`#{name}`"
    end

    # from active_record/vendor/mysql.rb
    def quote_string(str) #:nodoc:
      str.gsub(/([\0\n\r\032\'\"\\])/) do
        case $1
        when "\0" then "\\0"
        when "\n" then "\\n"
        when "\r" then "\\r"
        when "\032" then "\\Z"
        else "\\"+$1
        end
      end
    end
    
    def quoted_true
        "1"
    end
    
    def quoted_false
        "0"
    end
    
    # SCHEMA STATEMENTS ========================================
    
    def structure_dump #:nodoc:
      if supports_views?
        sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"
      else
        sql = "SHOW TABLES"
      end
      
      select_all(sql).inject("") do |structure, table|
        table.delete('Table_type')
        structure += select_one("SHOW CREATE TABLE #{table.to_a.first.last}")["Create Table"] + ";\n\n"
      end
    end
    
    def recreate_database(name) #:nodoc:
      drop_database(name)
      create_database(name)
    end
    
    def create_database(name) #:nodoc:
      execute "CREATE DATABASE `#{name}`"
    end
    
    def drop_database(name) #:nodoc:
      execute "DROP DATABASE IF EXISTS `#{name}`"
    end
    
    def current_database
      select_one("SELECT DATABASE() as db")["db"]
    end
    
    def indexes(table_name, name = nil)#:nodoc:
      indexes = []
      current_index = nil
      execute("SHOW KEYS FROM #{table_name}", name).each do |row|
        if current_index != row[2]
          next if row[2] == "PRIMARY" # skip the primary key
          current_index = row[2]
          indexes << IndexDefinition.new(row[0], row[2], row[1] == "0", [])
        end
        
        indexes.last.columns << row[4]
      end
      indexes
    end
    
    def create_table(name, options = {}) #:nodoc:
      super(name, {:options => "ENGINE=InnoDB"}.merge(options))
    end
    
    def rename_table(name, new_name)
      execute "RENAME TABLE #{name} TO #{new_name}"
    end  
    
    def change_column_default(table_name, column_name, default) #:nodoc:
      current_type = select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")["Type"]
      
      change_column(table_name, column_name, current_type, { :default => default })
    end
    
    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      options[:default] ||= select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")["Default"]
      
      change_column_sql = "ALTER TABLE #{table_name} CHANGE #{column_name} #{column_name} #{type_to_sql(type, options[:limit])}"
      add_column_options!(change_column_sql, options)
      execute(change_column_sql)
    end
    
    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      current_type = select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")["Type"]
      execute "ALTER TABLE #{table_name} CHANGE #{column_name} #{new_column_name} #{current_type}"
    end
  end

  module Derby
    def modify_types(tp)
      tp[:primary_key] = "int generated by default as identity NOT NULL PRIMARY KEY"
      tp
    end

    def add_limit_offset!(sql, options) # :nodoc:
      @limit = options[:limit]
      @offset = options[:offset]
    end
    
    def select_all(sql, name = nil)
      @limit ||= -1
      @offset ||= 0
      select(sql, name)[@offset..(@offset+@limit)]
    ensure
      @limit = @offset = nil
    end
    
    def select_one(sql, name = nil)
      @offset ||= 0
      select(sql, name)[@offset]
    ensure
      @limit = @offset = nil
    end

    def execute(sql, name = nil)
      log_no_bench(sql, name) do
        if sql =~ /^select/i
          @limit ||= -1
          @offset ||= 0
          @connection.execute_query(sql)[@offset..(@offset+@limit)]
        else
          @connection.execute_update(sql)
        end
      end
    ensure
      @limit = @offset = nil
    end
  end
  
  module FireBird
    def modify_types(tp)
      tp[:primary_key] = 'INTEGER NOT NULL PRIMARY KEY'
      tp[:string][:limit] = 252
      tp
    end
    
    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) # :nodoc:
      execute(sql, name)
      id_value
    end

    def add_limit_offset!(sql, options) # :nodoc:
      if options[:limit]
        limit_string = "FIRST #{options[:limit]}"
        limit_string << " SKIP #{options[:offset]}" if options[:offset]
        sql.sub!(/\A(\s*SELECT\s)/i, '\&' + limit_string + ' ')
      end
    end

    def prefetch_primary_key?(table_name = nil)
      true
    end

    def default_sequence_name(table_name, primary_key) # :nodoc:
      "#{table_name}_seq"
    end
    
    def next_sequence_value(sequence_name)
      select_one("SELECT GEN_ID(#{sequence_name}, 1 ) FROM RDB$DATABASE;")["gen_id"]
    end
    
    def create_table(name, options = {}) #:nodoc:
      super(name, options)
      execute "CREATE GENERATOR #{name}_seq"
    end

    def rename_table(name, new_name) #:nodoc:
      execute "RENAME #{name} TO #{new_name}"
      execute "UPDATE RDB$GENERATORS SET RDB$GENERATOR_NAME='#{new_name}_seq' WHERE RDB$GENERATOR_NAME='#{name}_seq'" rescue nil
    end  

    def drop_table(name) #:nodoc:
      super(name)
      execute "DROP GENERATOR #{name}_seq" rescue nil
    end
  end
  
  module DB2
    def modify_types(tp)
      tp[:primary_key] = 'int generated by default as identity (start with 42) primary key'
      tp[:string][:limit] = 255
      tp
    end
    
    def add_limit_offset!(sql, options)
      if limit = options[:limit]
        offset = options[:offset] || 0
        sql.gsub!(/SELECT/i, 'SELECT B.* FROM (SELECT A.*, row_number() over () AS internal$rownum FROM (SELECT')
        sql << ") A ) B WHERE B.internal$rownum > #{offset} AND B.internal$rownum <= #{limit + offset}"
      end
    end
  end
  
  module MsSQL
    def modify_types(tp)
      tp[:primary_key] = "int NOT NULL IDENTITY(1, 1) PRIMARY KEY"
      tp
    end
    
    def add_limit_offset!(sql, options)
      if options[:limit] and options[:offset]
        total_rows = @connection.select_all("SELECT count(*) as TotalRows from (#{sql.gsub(/\bSELECT\b/i, "SELECT TOP 1000000000")}) tally")[0][:TotalRows].to_i
        if (options[:limit] + options[:offset]) >= total_rows
          options[:limit] = (total_rows - options[:offset] >= 0) ? (total_rows - options[:offset]) : 0
        end
        sql.sub!(/^\s*SELECT/i, "SELECT * FROM (SELECT TOP #{options[:limit]} * FROM (SELECT TOP #{options[:limit] + options[:offset]} ")
        sql << ") AS tmp1"
        if options[:order]
          options[:order] = options[:order].split(',').map do |field|
            parts = field.split(" ")
            tc = parts[0]
            if sql =~ /\.\[/ and tc =~ /\./ # if column quoting used in query
              tc.gsub!(/\./, '\\.\\[')
              tc << '\\]'
            end
            if sql =~ /#{tc} AS (t\d_r\d\d?)/
              parts[0] = $1
            end
            parts.join(' ')
          end.join(', ')
          sql << " ORDER BY #{change_order_direction(options[:order])}) AS tmp2 ORDER BY #{options[:order]}"
        else
          sql << " ) AS tmp2"
        end
      elsif sql !~ /^\s*SELECT (@@|COUNT\()/i
        sql.sub!(/^\s*SELECT([\s]*distinct)?/i) do
          "SELECT#{$1} TOP #{options[:limit]}"
        end unless options[:limit].nil?
      end
    end
  end
end
