# this file is discovered by the extension mechanism
# @see {ArJdbc#discover_extensions}

module ArJdbc

  require 'arjdbc/jdbc/adapter_require'

  # Adapters built-in to AR :

  require 'arjdbc/mysql' if ENV_JAVA['arjdbc.mysql.eager_load'].eql? 'true'
  require 'arjdbc/postgresql' if ENV_JAVA['arjdbc.postgresql.eager_load'].eql? 'true'
  require 'arjdbc/sqlite3' if ENV_JAVA['arjdbc.sqlite3.eager_load'].eql? 'true'

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

      if config && config[:username].nil? # set the database schema name (:username) :
        begin
          ArJdbc.with_meta_data_from_data_source_if_any(config) do
            |meta_data| config[:username] = meta_data.getUserName
          end
        rescue => e
          ArJdbc.warn("failed to set :username from (Derby) database meda-data: #{e}")
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

end
