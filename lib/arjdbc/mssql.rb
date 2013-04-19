require 'arjdbc'
ArJdbc.load_java_part :MSSQL
require 'arjdbc/mssql/adapter'
require 'arjdbc/mssql/connection_methods'
module ArJdbc
  MsSQL = MSSQL # compatibility with 1.2
end