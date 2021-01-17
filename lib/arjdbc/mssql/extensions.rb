# This file contains extensions, overrides, and monkey patches to core parts
# of active record to allow SQL Server work properly.
#
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module AttributeMethods

        private

        # Overrides the original attributes_for_update merthod to reject
        # primary keys because SQL Server does not allow updates
        # of identity columns.
        # NOTE: rails 4.1 used to reject primary keys but later changes broke
        # this behaviour, even the current comments for that method says that
        # it rejects primary key but it doesn't (maybe a rails bug?)
        def attributes_for_update(attribute_names)
          attribute_names.reject do |name|
            # It seems is only required to check if column in identity or not.
            # This allows to update rails custom primary keys
            next true if readonly_attribute?(name)

            column = self.class.columns_hash[name]
            column && column.identity?
          end
        end
      end
    end
  end
end

module ActiveRecord
  class Base
    include ActiveRecord::ConnectionAdapters::MSSQL::AttributeMethods
  end
end
