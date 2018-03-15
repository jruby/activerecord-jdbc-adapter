module ActiveRecord
  module ConnectionAdapters
    module SQLServer
      module CoreExt
        module AttributeMethods


          private

          def attributes_for_update(attribute_names)
            super.reject do |name|
              column = self.class.columns_hash[name]
              column && column.respond_to?(:identity?) && column.identity?
            end
          end

        end
      end
    end
  end
end
ActiveRecord::Base.send :include, ActiveRecord::ConnectionAdapters::SQLServer::CoreExt::AttributeMethods
