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

        def real(*args, **options)
          args.each { |name| column(name, :real, options) }
        end

        def money(*args, **options)
          args.each { |name| column(name, :money, options) }
        end

        def smallmoney(*args, **options)
          args.each { |name| column(name, :smallmoney, options) }
        end

        def char(*args, **options)
          args.each { |name| column(name, :char, options) }
        end

        def varchar(*args, **options)
          args.each { |name| column(name, :varchar, options) }
        end

        def varchar_max(*args, **options)
          args.each { |name| column(name, :varchar_max, options) }
        end

        def text_basic(*args, **options)
          args.each { |name| column(name, :text_basic, options) }
        end

        def nchar(*args, **options)
          args.each { |name| column(name, :nchar, options) }
        end

        def ntext(*args, **options)
          args.each { |name| column(name, :ntext, options) }
        end

        def binary_basic(*args, **options)
          args.each { |name| column(name, :binary_basic, options) }
        end

        def varbinary(*args, **options)
          args.each { |name| column(name, :varbinary, options) }
        end

        def uuid(*args, **options)
          args.each { |name| column(name, :uniqueidentifier, options) }
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
