require 'arjdbc/hsqldb/adapter'

module ArJdbc
  module H2
    include HSQLDB

    def adapter_name #:nodoc:
      'H2'
    end

    def h2_adapter
      true
    end

    def tables
      @connection.tables(nil, h2_schema)
    end

    def columns(table_name, name=nil)
      @connection.columns_internal(table_name.to_s, name, h2_schema)
    end

    private
    def h2_schema
      @config[:schema] || ''
    end
  end
end
