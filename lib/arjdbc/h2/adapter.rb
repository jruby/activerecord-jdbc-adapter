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
  end
end
