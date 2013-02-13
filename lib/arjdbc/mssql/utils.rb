# NOTE: lot of code kindly borrowed from __activerecord-sqlserver-adapter__
module ArJdbc
  module MSSQL
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
      
      def get_primary_key(order, table_name)
        if order =~ /(\w*id\w*)/i
          $1
        else
          name = unquote_table_name(table_name)
          model = descendants.select { |m| m.table_name == name }.first
          model ? model.primary_key : 'id'
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
      
      private
      
      if ActiveRecord::VERSION::MAJOR >= 3
        def descendants; ::ActiveRecord::Base.descendants; end
      else
        def descendants; ::ActiveRecord::Base.send(:subclasses) end
      end
      
    end
  end
end