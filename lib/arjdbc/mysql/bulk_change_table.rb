module ArJdbc
  module MySQL
    module BulkChangeTable

      # @override
      def supports_bulk_alter?
        true
      end

      def bulk_change_table(table_name, operations)
        sqls = operations.map do |command, args|
          table, arguments = args.shift, args
          method = :"#{command}_sql"

          if respond_to?(method, true)
            send(method, table, *arguments)
          else
            raise "Unknown method called : #{method}(#{arguments.inspect})"
          end
        end
        sqls.flatten!

        execute("ALTER TABLE #{quote_table_name(table_name)} #{sqls.join(", ")}")
      end

      protected

      def add_column_sql(table_name, column_name, type, options = {})
        add_column_sql = "ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(add_column_sql, options)
        add_column_position!(add_column_sql, options)
        add_column_sql
      end

      def change_column_sql(table_name, column_name, type, options = {})
        column = column_for(table_name, column_name)

        unless options_include_default?(options)
          options[:default] = column.default
        end

        unless options.has_key?(:null)
          options[:null] = column.null
        end

        change_column_sql = "CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(change_column_sql, options)
        add_column_position!(change_column_sql, options)
        change_column_sql
      end

      def rename_column_sql(table_name, column_name, new_column_name)
        options = {}

        if column = columns(table_name).find { |c| c.name == column_name.to_s }
          options[:default] = column.default
          options[:null] = column.null
          options[:auto_increment] = (column.extra == "auto_increment")
        else
          raise ActiveRecordError, "No such column: #{table_name}.#{column_name}"
        end

        current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'", 'SCHEMA')["Type"]
        rename_column_sql = "CHANGE #{quote_column_name(column_name)} #{quote_column_name(new_column_name)} #{current_type}"
        add_column_options!(rename_column_sql, options)
        rename_column_sql
      end

      def remove_column_sql(table_name, column_name, type = nil, options = {})
        "DROP #{quote_column_name(column_name)}"
      end

      def remove_columns_sql(table_name, *column_names)
        column_names.map {|column_name| remove_column_sql(table_name, column_name) }
      end

      def add_index_sql(table_name, column_name, options = {})
        index_name, index_type, index_columns = add_index_options(table_name, column_name, options)
        "ADD #{index_type} INDEX #{index_name} (#{index_columns})"
      end

      def remove_index_sql(table_name, options = {})
        index_name = index_name_for_remove(table_name, options)
        "DROP INDEX #{index_name}"
      end

      def add_timestamps_sql(table_name)
        [add_column_sql(table_name, :created_at, :datetime), add_column_sql(table_name, :updated_at, :datetime)]
      end

      def remove_timestamps_sql(table_name)
        [remove_column_sql(table_name, :updated_at), remove_column_sql(table_name, :created_at)]
      end

      private

      def add_column_position!(sql, options)
        if options[:first]
          sql << " FIRST"
        elsif options[:after]
          sql << " AFTER #{quote_column_name(options[:after])}"
        end
      end

    end
  end
end
