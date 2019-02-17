module ActiveRecord
  module ConnectionAdapters
    # MSSQL specific extensions to column definitions in a table.
    class MSSQLColumn < Column

      def identity?
        !! sql_type.downcase.index('identity')
      end
      # @deprecated
      alias_method :identity, :identity?
      alias_method :is_identity, :identity?

    end
  end
end
