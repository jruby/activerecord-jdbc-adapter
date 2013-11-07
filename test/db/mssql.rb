require 'test_helper'

if ['SQLJDBC', 'SQLSERVER'].include? ENV['DRIVER'].to_s.upcase
  require 'db/sqlserver'
else # currently jTDS is the default driver
  require 'db/mssql_config'
  ActiveRecord::Base.establish_connection(MSSQL_CONFIG)
end