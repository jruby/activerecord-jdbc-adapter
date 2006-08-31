
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
      tp
    end
  end
end
