module ArJdbc
  module MSSQL
    # @note Lot of code kindly borrowed from **activerecord-sqlserver-adapter**.
    module Utils

      module_function

      GET_TABLE_NAME_INSERT_UPDATE_RE =
        /^\s*(INSERT|EXEC sp_executesql N'INSERT)\s+INTO\s+([^\(\s,]+)\s*|^\s*update\s+([^\(\s,]+)\s*/i

      GET_TABLE_NAME_FROM_RE = /\bFROM\s+([^\(\)\s,]+)\s*/i

      def get_table_name(sql, qualified = nil)
        if sql =~ GET_TABLE_NAME_INSERT_UPDATE_RE
          tn = $2 || $3
          qualified ? tn : unqualify_table_name(tn)
        elsif sql =~ GET_TABLE_NAME_FROM_RE
          qualified ? $1 : unqualify_table_name($1)
        else
          nil
        end
      end

      # protected

      def unquote_table_name(table_name)
        unquote_column_name(table_name)
      end

      def unquote_column_name(column_name)
        column_name.to_s.tr('[]', '')
      end

      def unquote_string(string)
        string.to_s.gsub("''", "'")
      end

      def unqualify_table_name(table_name)
        table_name.to_s.split('.').last.tr('[]', '')
      end

      def unqualify_table_schema(table_name)
        table_name.to_s.split('.')[-2].gsub(/[\[\]]/, '') rescue nil
      end

      def unqualify_db_name(table_name)
        table_names = table_name.to_s.split('.')
        table_names.length == 3 ? table_names.first.tr('[]', '') : nil
      end

    end
  end
end