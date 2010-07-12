# Built-in vendor adapters
module ::ArJdbc
  module CacheDB
    def self.adapter_matcher(name, *)
      require 'arjdbc/cachedb'
      name =~ /cache/i ? self : false
    end
  end

  module DB2
    def self.adapter_matcher(name, config)
      require 'arjdbc/db2'
      if name =~ /db2/i
         return config[:url] =~ /^jdbc:derby:net:/ ? ::ArJdbc::Derby : self
      end
      false
    end
  end

  module Derby
    def self.adapter_matcher(name, *)
      require 'arjdbc/derby'
      name =~ /derby/i ? self : false
    end
  end

  module FireBird
    def self.adapter_matcher(name, *)
      require 'arjdbc/firebird'
      name =~ /firebird/i ? self : false
    end
  end

  module H2
    def self.adapter_matcher(name, *)
      require 'arjdbc/h2'
      name =~ /\.h2\./i ? self : false
    end
  end

  module HSQLDB
    def self.adapter_matcher(name, *)
      require 'arjdbc/hsqldb'
      name =~ /hsqldb/i ? self : false
    end
  end

  module Informix
    def self.adapter_matcher(name, *)
      require 'arjdbc/informix'
      name =~ /informix/i ? self : false
    end
  end

  module Mimer
    def self.adapter_matcher(name, *)
      require 'arjdbc/mimer'
      name =~ /mimer/i ? self : false
    end
  end

  module MsSQL
    def self.adapter_matcher(name, *)
      require 'arjdbc/mssql'
      name =~ /sqlserver|tds/i ? self : false
    end
  end

  module MySQL
    def self.adapter_matcher(name, *)
      require 'arjdbc/mysql'
      name =~ /mysql/i ? self : false
    end
  end

  module Oracle
    def self.adapter_matcher(name, *)
      require 'arjdbc/oracle'
      name =~ /oracle/i ? self : false
    end
  end

  module PostgreSQL
    def self.adapter_matcher(name, *)
      require 'arjdbc/postgresql'
      name =~ /postgre/i ? self : false
    end
  end

  module SQLite3
    def self.adapter_matcher(name, *)
      require 'arjdbc/sqlite3'
      name =~ /sqlite/i ? self : false
    end
  end

  module Sybase
    def self.adapter_matcher(name, *)
      require 'arjdbc/sybase'
      name =~ /sybase|tds/i ? self : false
    end
  end
end
