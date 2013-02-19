require 'test_helper'

MSSQL_CONFIG = { :adapter  => 'mssql' }
MSSQL_CONFIG[:database] = ENV['SQLDATABASE'] || 'weblog_development'
MSSQL_CONFIG[:username] = ENV['SQLUSER'] || 'blog'
MSSQL_CONFIG[:password] = ENV['SQLPASS'] || ''

MSSQL_CONFIG[:host] = ENV['SQLHOST'] || 'localhost'
MSSQL_CONFIG[:port] = ENV['SQLPORT'] if ENV['SQLPORT']

ActiveRecord::Base.establish_connection(MSSQL_CONFIG)
