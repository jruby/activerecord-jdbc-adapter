require 'arjdbc/hsqldb/adapter'

module ArJdbc
  module H2
    include HSQLDB

    def self.adapter_matcher(name, *)
      name =~ /\.h2\./i ? self : false
    end

    def adapter_name #:nodoc:
      'H2'
    end

    def h2_adapter
      true
    end
  end
end
