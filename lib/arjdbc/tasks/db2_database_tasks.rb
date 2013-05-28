require 'arjdbc/tasks/jdbc_database_tasks'

module ArJdbc
  module Tasks
    class DB2DatabaseTasks < JdbcDatabaseTasks

      def create
        raise "AR-JDBC adapter 'DB2' does not support create_database"
      end
      
      def purge
        establish_connection(config)
        connection.recreate_database
      end
      
      # NOTE: does not work correctly (on non AS400) due driver meta data issue
      # 
      # also try db2move e.g. `db2move SAMPLE EXPORT -sn db2inst` 
      # - where SAMPLE is the database name
      # - and -sn specified schema name
      # 
      
      def structure_dump(filename)
        establish_connection(config)
        dump = File.open(filename, "w:utf-8")
        
        schema_name = connection.schema.upcase if connection.schema
        meta_data = connection.jdbc_connection.meta_data
        tables_rs = meta_data.getTables(nil, schema_name, nil, ["TABLE"].to_java(:String))
        
        have_scale = ArJdbc::DB2::HAVE_SCALE
        have_precision = ArJdbc::DB2::HAVE_LIMIT + ArJdbc::DB2::HAVE_LIMIT
        
        while tables_rs.next
          table_name = tables_rs.getString('TABLE_NAME')
          dump << "CREATE TABLE #{connection.quote_table_name(table_name)} (\n"
          
          cols_rs = meta_data.getColumns(nil, schema_name, table_name, nil)
          begin
            first_col = true
            while cols_rs.next
              column_name = cols_rs.getString(4)
              default = cols_rs.getString(13)
              default = default.empty? ? "" : " DEFAULT #{default}" if default
              type = cols_rs.getString(6)
              precision, scale = cols_rs.getString(7), cols_rs.getString(9)
              column_size = ""
              if scale && have_scale.include?(type)
                column_size = "(#{precision},#{scale})"
              elsif precision && have_precision.include?(type)
                column_size = "(#{precision})"
              end
              nulling = ( cols_rs.getString(18) == 'NO' ? " NOT NULL" : nil )
              autoinc = ( cols_rs.getString(23) == 'YES' ? " GENERATED ALWAYS AS IDENTITY" : nil )
              
              create_column = connection.quote_column_name(column_name)
              create_column << " #{type}"
              create_column << column_size
              create_column << nulling.to_s
              create_column << default.to_s
              create_column << autoinc.to_s
              
              create_column = first_col ? "  #{create_column}" : ",\n  #{create_column}"
              dump << create_column

              first_col = false
            end
          ensure
            cols_rs.close
          end

          dump << "\n);\n\n"

          pk_rs = meta_data.getPrimaryKeys(nil, schema_name, table_name)
          primary_keys = {}
          begin
            while pk_rs.next
              name = pk_rs.getString(6)
              primary_keys[name] ||= []
              primary_keys[name] << pk_rs.getString(4)
            end
          ensure
            pk_rs.close
          end
          primary_keys.each do |name, cols|
            dump << "ALTER TABLE #{connection.quote_table_name(table_name)}\n"
            dump << "  ADD CONSTRAINT #{name}\n"
            dump << "    PRIMARY KEY (#{cols.join(', ')});\n\n"
          end
        end
        
        dump.close
      end
      
      def structure_load(filename)
        establish_connection(config)
        IO.read(filename).split(/;\n*/m).each do |ddl| 
          connection.execute ddl.sub(/;$/, '')
        end
      end
      
    end
  end
end