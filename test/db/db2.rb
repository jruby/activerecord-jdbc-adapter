require 'test_helper'

config = { :adapter => "db2" }

config[:host] = ENV['DB2HOST'] if ENV['DB2HOST']
config[:port] = ENV['DB2PORT'] if ENV['DB2PORT']
# DB2 uses $USER if running locally, just add
# yourself to your db2 groups in /etc/group
config[:username] = ENV['DB2USER'] if ENV['DB2USER'] # db2inst1
config[:password] = ENV['DB2PASS'] if ENV['DB2PASS']

# DB2 does not like "_" in database names :
# SQL0104N  An unexpected token "weblog_development" was found
# create the sample database using `db2sampl` command
database = ENV['DB2DATABASE'] || 'SAMPLE'
if config[:host]
  config[:database] = database
else
  config[:url] = "jdbc:db2:#{database}" # local instance
end

require 'jdbc/db2'
# Download IBM DB2 JCC driver from :
# https://www-304.ibm.com/support/docview.wss?rs=4020&uid=swg21385217
begin
  Java::JavaClass.for_name(Jdbc::DB2.driver_name)
rescue NameError
  begin
    Jdbc::DB2.load_driver
  rescue LoadError => e
    puts "Please setup a JDBC driver to run the DB2 tests !"
    raise e
  end
end

ActiveRecord::Base.establish_connection(config)
