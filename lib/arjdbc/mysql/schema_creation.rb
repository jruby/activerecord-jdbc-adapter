module ArJdbc
  module MySQL
    # @private copied from native adapter 4.0/4.1
    class SchemaCreation < ::ActiveRecord::ConnectionAdapters::AbstractAdapter::SchemaCreation

      def visit_AddColumn(o)
        add_column_position!(super, column_options(o))
      end

      private
      def visit_ChangeColumnDefinition(o)
        column = o.column
        options = o.options
        sql_type = type_to_sql(o.type, options[:limit], options[:precision], options[:scale])
        change_column_sql = "CHANGE #{quote_column_name(column.name)} #{quote_column_name(options[:name])} #{sql_type}"
        add_column_options!(change_column_sql, options)
        add_column_position!(change_column_sql, options)
      end

      def add_column_position!(sql, options)
        if options[:first]
          sql << " FIRST"
        elsif options[:after]
          sql << " AFTER #{quote_column_name(options[:after])}"
        end
        sql
      end
    end
  end

  def schema_creation
    SchemaCreation.new self
  end

end if ::ActiveRecord::ConnectionAdapters::AbstractAdapter.const_defined? :SchemaCreation