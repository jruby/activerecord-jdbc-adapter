require 'test_helper'

config = {
  :adapter  => 'oracle',
  :username => ENV["ORACLE_USER"] || 'blog',
  :password => ENV["ORACLE_PASS"] || 'blog',
  :host => ENV["ORACLE_HOST"] || 'localhost',
  :database => ENV["ORACLE_SID"] || 'XE',
  :prepared_statements => ENV['PREPARED_STATEMENTS'] || ENV['PS']
}

ActiveRecord::Base.establish_connection(config)

require 'jdbc/oracle'
# Download JDBC driverfrom :
# http://www.oracle.com/technetwork/database/enterprise-edition/jdbc-112010-090769.html
begin
  Java::JavaClass.for_name(Jdbc::Oracle.driver_name)
rescue NameError
  begin
    Jdbc::Oracle.load_driver
  rescue LoadError => e
    puts "Please setup a JDBC driver to run the Oracle tests !"
    raise e
  end
end

ActiveRecord::Base.establish_connection(config)
