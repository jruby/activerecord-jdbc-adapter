# This patches the Name class so that it doesn't use pg gem specific quoting
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class Name

        def quoted
          if schema
            "#{quote_identifier(schema)}#{SEPARATOR}#{quote_identifier(identifier)}"
          else
            quote_identifier(identifier)
          end
        end

        private

        def quote_identifier(name)
          %("#{name.to_s.gsub("\"", "\"\"")}")
        end

      end
    end
  end
end
