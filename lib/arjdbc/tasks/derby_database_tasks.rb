require 'arjdbc/tasks/jdbc_database_tasks'

module ArJdbc
  module Tasks
    class DerbyDatabaseTasks < JdbcDatabaseTasks

      def drop
        db_dir = expand_path(config['database'])
        if File.exist?(db_dir)
          FileUtils.rm_r(db_dir)
          FileUtils.rmdir(db_dir)
        end
      end
      alias :purge :drop
      
      SIZEABLE = %w( VARCHAR CLOB BLOB )

      def structure_dump(filename)
        establish_connection(config)
        dump = File.open(filename, "w:utf-8")
        meta_data = connection.jdbc_connection.meta_data
        tables_rs = meta_data.getTables(nil, nil, nil, ["TABLE"].to_java(:string))
        while tables_rs.next
          table_name = tables_rs.getString(3)
          dump << "CREATE TABLE #{table_name} (\n"
          columns_rs = meta_data.getColumns(nil, nil, table_name, nil)
          first_col = true
          while columns_rs.next
            column_name = add_quotes(columns_rs.getString(4));
            default = ''
            d1 = columns_rs.getString(13)
            if d1 =~ /^GENERATED_/
              default = column_auto_increment_def(table_name, column_name)
            elsif d1
              default = " DEFAULT #{d1}"
            end

            type = columns_rs.getString(6)
            column_size = columns_rs.getString(7)
            nulling = (columns_rs.getString(18) == 'NO' ? " NOT NULL" : "")
            create_column = add_quotes(expand_double_quotes(strip_quotes(column_name)))
            create_column << " #{type}"
            create_column << ( SIZEABLE.include?(type) ? "(#{column_size})" : "" )
            create_column << nulling
            create_column << default

            create_column = first_col ? " #{create_column}" : ",\n #{create_column}"
            dump << create_column

            first_col = false
          end
          dump << "\n);\n\n"
        end
        dump.close
      end
      
      def structure_load(filename)
        establish_connection(config)
        IO.read(filename).split(/;\n*/m).each { |ddl| connection.execute(ddl) }
      end
      
      private

      AUTO_INCREMENT_SQL = '' <<
      "SELECT AUTOINCREMENTSTART, AUTOINCREMENTINC, COLUMNNAME, REFERENCEID, COLUMNDEFAULT " <<
      "FROM SYS.SYSCOLUMNS WHERE REFERENCEID = " <<
      "(SELECT T.TABLEID FROM SYS.SYSTABLES T WHERE T.TABLENAME = '%s') AND COLUMNNAME = '%s'"

      def column_auto_increment_def(table_name, column_name)
        sql = AUTO_INCREMENT_SQL % [ table_name, strip_quotes(column_name) ]
        if data = connection.execute(sql).first
          if start = data['autoincrementstart']
            ai_def = ' GENERATED '
            ai_def << ( data['columndefault'].nil? ? "ALWAYS" : "BY DEFAULT " )
            ai_def << "AS IDENTITY (START WITH "
            ai_def << start.to_s
            ai_def << ", INCREMENT BY "
            ai_def << data['autoincrementinc'].to_s
            ai_def << ")"
            return ai_def
          end
        end
        ''
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
        name.gsub('"', '""')
      end
      
    end
  end
end