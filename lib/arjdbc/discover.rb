# this file is discovered by the extension mechanism 
# @see {ArJdbc#discover_extensions}

module ArJdbc
  
  require 'arjdbc/jdbc/adapter_require'
  
  # Adapters built-in to AR :
  
  require 'arjdbc/mysql' if Java::JavaLang::Boolean.getBoolean('arjdbc.mysql.eager_load')
  require 'arjdbc/postgresql' if Java::JavaLang::Boolean.getBoolean('arjdbc.postgresql.eager_load')
  require 'arjdbc/sqlite3' if Java::JavaLang::Boolean.getBoolean('arjdbc.sqlite3.eager_load')
  
  extension :MySQL do |name|
    require('arjdbc/mysql') || true if name =~ /mysql/i
  end
  
  extension :PostgreSQL do |name|
    require('arjdbc/postgresql') || true if name =~ /postgre/i
  end

  extension :SQLite3 do |name|
    require('arjdbc/sqlite3') || true if name =~ /sqlite/i
  end
  
  # Other supported adapters :

  extension :Derby do |name, config|
    if name =~ /derby/i
      require 'arjdbc/derby'

      # Derby-specific hack
      if config && ! config[:username] && ( config[:jndi] || config[:data_source] )
        # Needed to set the correct database schema name (:username)
        begin
          data_source = config[:data_source] || Java::JavaxNaming::InitialContext.new.lookup(config[:jndi])
          connection = data_source.getConnection
          config[:username] = connection.getMetaData.getUserName
        rescue Java::JavaSql::SQLException => e
          warn "failed to set (derby) database :username from connection meda-data (#{e})"
        ensure
          ( connection.close rescue nil ) if connection # return to the pool
        end
      end

      true
    end
  end

  extension :H2 do |name|
    require('arjdbc/h2') || true if name =~ /\.h2\./i
  end

  extension :HSQLDB do |name|
    require('arjdbc/hsqldb') || true if name =~ /hsqldb/i
  end

  extension :MSSQL do |name|
    require('arjdbc/mssql') || true if name =~ /sqlserver|tds|Microsoft SQL/i
  end

  extension :DB2 do |name, config|
    if name =~ /db2/i && name !~ /as\/?400/i && config[:url] !~ /^jdbc:derby:net:/
      require 'arjdbc/db2'
      true
    end
  end
  
  extension :AS400 do |name, config|
    # The native JDBC driver always returns "DB2 UDB for AS/400"
    if name =~ /as\/?400/i
      require 'arjdbc/db2'
      require 'arjdbc/db2/as400'
      true
    end
  end

  extension :Oracle do |name|
    if name =~ /oracle/i
      require 'arjdbc/oracle'
      true
    end
  end
  
  # NOTE: following ones are likely getting deprecated :
  
  extension :FireBird do |name|
    if name =~ /firebird/i
      require 'arjdbc/firebird'
      true
    end
  end

  extension :Sybase do |name|
    if name =~ /sybase|tds/i
      require 'arjdbc/sybase'
      true
    end
  end
  
  extension :Informix do |name|
    if name =~ /informix/i
      require 'arjdbc/informix'
      true
    end
  end

  extension :Mimer do |name|
    if name =~ /mimer/i
      require 'arjdbc/mimer'
      true
    end
  end
  
end
