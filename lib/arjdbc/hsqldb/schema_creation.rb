module ArJdbc
  module HSQLDB
    # @private
    SchemaCreation = ::ActiveRecord::ConnectionAdapters::AbstractAdapter::SchemaCreation

    def schema_creation
      SchemaCreation.new self
    end

  end
end if ::ActiveRecord::ConnectionAdapters::AbstractAdapter.const_defined? :SchemaCreation