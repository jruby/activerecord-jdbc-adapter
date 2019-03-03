module ActiveRecord
  module ConnectionAdapters
    # MSSQL specific extensions to column definitions in a table.
    class MSSQLColumn < Column
      def initialize(name, raw_default, sql_type_metadata = nil, null = true, table_name = nil, default_function = nil, collation = nil, comment: nil)
        default = extract_default(raw_default)

        super(name, default, sql_type_metadata, null, table_name, default_function, collation, comment: comment)
      end

      def extract_default(value)
        return $1 if value =~ /^\(N?'(.*)'\)$/ || value =~ /^\(\(?(.*?)\)?\)$/
        value
      end

      def identity?
        sql_type.downcase.include? 'identity'
      end

    end
  end
end
