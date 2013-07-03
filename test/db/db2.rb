require 'test_helper'

config = { :adapter => "db2" }

config[:host] = ENV['DB2HOST'] if ENV['DB2HOST']
config[:port] = ENV['DB2PORT'] if ENV['DB2PORT']
# DB2 uses $USER if running locally, just add
# yourself to your db2 groups in /etc/group
config[:username] = ENV['DB2USER'] if ENV['DB2USER'] # db2inst1
config[:password] = ENV['DB2PASS'] if ENV['DB2PASS']

# for AS400 specify the full JDBC URL "jdbc:as400://..."
config[:url] = ENV['DB2URL'] if ENV['DB2URL']

# DB2 does not like "_" in database names :
# SQL0104N  An unexpected token "weblog_development" was found
# create the sample database using `db2sampl` command
unless config[:url]
  database = ENV['DB2DATABASE'] || 'SAMPLE'
  if config[:host]
    config[:database] = database
  else
    config[:url] = "jdbc:db2:#{database}" # local instance
  end
end

config[:prepared_statements] = ENV['PREPARED_STATEMENTS'] || ENV['PS']

require 'jdbc/db2'
# Download IBM DB2 JCC driver from :
# https://www-304.ibm.com/support/docview.wss?rs=4020&uid=swg21385217
# or http://sourceforge.net/projects/jt400/ for AS400
jdbc_db2 = (config[:url] || '') =~ /\:as400/ ? Jdbc::AS400 : Jdbc::DB2
begin
  silence_warnings { Java::JavaClass.for_name(jdbc_db2.driver_name) }
rescue NameError
  begin
    jdbc_db2.load_driver
  rescue LoadError => e
    warn "Please setup a JDBC driver to run the DB2 tests !"
    raise e
  end
end

ActiveRecord::Base.establish_connection(config)
