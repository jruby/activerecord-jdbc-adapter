# Built-in vendor adapters
module ::ArJdbc
  # Adapters built-in to AR are required up-front so we can override
  # the native ones
  require 'arjdbc/mysql'
  module MySQL
    def self.adapter_matcher(name, *)
      name =~ /mysql/i ? self : false
    end
  end

  require 'arjdbc/postgresql'
  module PostgreSQL
    def self.adapter_matcher(name, *)
      name =~ /postgre/i ? self : false
    end
  end

  require 'arjdbc/sqlite3'
  module SQLite3
    def self.adapter_matcher(name, *)
      name =~ /sqlite/i ? self : false
    end
  end

  # Other adapters are lazy-loaded
  module CacheDB
    def self.adapter_matcher(name, *)
      return false unless name =~ /cache/i
      require 'arjdbc/cachedb'
      self
    end
  end

  module DB2
    def self.adapter_matcher(name, config)
      return false unless name =~ /db2/i && config[:url] !~ /^jdbc:derby:net:/
      require 'arjdbc/db2'
      self
    end
  end

  module Derby
    def self.adapter_matcher(name, *)
      return false unless name =~ /derby/i
      require 'arjdbc/derby'
      self
    end
  end

  module FireBird
    def self.adapter_matcher(name, *)
      return false unless name =~ /firebird/i
      require 'arjdbc/firebird'
      self
    end
  end

  module H2
    def self.adapter_matcher(name, *)
      return false unless name =~ /\.h2\./i
      require 'arjdbc/h2'
      self
    end
  end

  module HSQLDB
    def self.adapter_matcher(name, *)
      return false unless name =~ /hsqldb/i
      require 'arjdbc/hsqldb'
      self
    end
  end

  module Informix
    def self.adapter_matcher(name, *)
      return false unless name =~ /informix/i
      require 'arjdbc/informix'
      self
    end
  end

  module Mimer
    def self.adapter_matcher(name, *)
      return false unless name =~ /mimer/i
      require 'arjdbc/mimer'
      self
    end
  end

  module MsSQL
    def self.adapter_matcher(name, *)
      return false unless name =~ /sqlserver|tds/i
      require 'arjdbc/mssql'
      self
    end
  end

  module Oracle
    def self.adapter_matcher(name, *)
      return false unless name =~ /oracle/i
      require 'arjdbc/oracle'
      self
    end
  end

  module Sybase
    def self.adapter_matcher(name, *)
      return false unless name =~ /sybase|tds/i
      require 'arjdbc/sybase'
      self
    end
  end
end
