module ArJdbc
  module MSSQL

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn
    module Column

      def identity?
        !! sql_type.downcase.index('identity')
      end
      # @deprecated
      alias_method :identity, :identity?
      alias_method :is_identity, :identity?

    end
  end
end
