require 'arjdbc/tasks/jdbc_database_tasks'

module ArJdbc
  module Tasks
    class DerbyDatabaseTasks < JdbcDatabaseTasks

      def create
        establish_connection(config)
        ActiveRecord::Base.connection
      end

      def drop
        db_dir = expand_path resolve_database(config, true)
        if File.exist?(db_dir)
          FileUtils.rm_r(db_dir)
          FileUtils.rmdir(db_dir) rescue nil
        end
      end

      SIZEABLE = %w( VARCHAR CLOB BLOB )

      def structure_dump(filename)
        establish_connection(config)
        dump = File.open(filename, "w:utf-8")

        meta_data = connection.jdbc_connection.meta_data
        tables_rs = meta_data.getTables(nil, nil, nil, ["TABLE"].to_java(:String))

        while tables_rs.next
          table_name = tables_rs.getString('TABLE_NAME') # getString(3)
          dump << "CREATE TABLE #{connection.quote_table_name(table_name)} (\n"

          columns_rs = meta_data.getColumns(nil, nil, table_name, nil)
          first_col = true
          while columns_rs.next
            column_name = columns_rs.getString(4)
            default = columns_rs.getString(13)
            if default =~ /^GENERATED_/
              default = column_auto_increment_def(table_name, column_name)
            elsif default
              default = " DEFAULT #{default}"
            end
            type = columns_rs.getString(6)
            column_size = columns_rs.getString(7)
            nulling = ( columns_rs.getString(18) == 'NO' ? " NOT NULL" : nil )

            create_column = connection.quote_column_name(column_name)
            create_column << " #{type}"
            create_column << ( SIZEABLE.include?(type) ? "(#{column_size})" : "" )
            create_column << nulling.to_s
            create_column << default.to_s

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
        sql = AUTO_INCREMENT_SQL % [ table_name, column_name ]
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

    end
  end
end