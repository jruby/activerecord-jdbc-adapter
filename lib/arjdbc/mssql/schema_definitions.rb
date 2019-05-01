module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module ColumnMethods
        # datetime with seconds always zero (:00) and without fractional seconds
        def smalldatetime(*args, **options)
          args.each { |name| column(name, :smalldatetime, options) }
        end

        # this is the old sql server datetime type, the precision is as follow
        # xx1, xx3, and xx7
        def datetime_basic(*args, **options)
          args.each { |name| column(name, :datetime_basic, options) }
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
