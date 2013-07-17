require 'test_helper'
require 'db/mssql_config'

require 'jdbc/sqlserver' # using MS' (official) SQLJDBC driver
begin
  silence_warnings { Java::JavaClass.for_name(Jdbc::SQLServer.driver_name) }
rescue NameError
  begin
    Jdbc::SQLServer.load_driver
  rescue LoadError => e
    warn "Please setup the sqljdbc4.jar driver to run the MS-SQL tests !"
    raise e
  end
end

ActiveRecord::Base.establish_connection(MSSQL_CONFIG.merge(:adapter => 'sqlserver'))
