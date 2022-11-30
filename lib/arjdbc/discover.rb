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
  
  extension :H2 do |name|
    require('arjdbc/h2') || true if name =~ /\.h2\./i
  end

  extension :HSQLDB do |name|
    require('arjdbc/hsqldb') || true if name =~ /hsqldb/i
  end

  extension :MSSQL do |name|
    require('arjdbc/mssql') || true if name =~ /sqlserver|tds|Microsoft SQL/i
  end
end
