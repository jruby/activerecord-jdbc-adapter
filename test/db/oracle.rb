require 'test_helper'

config = {
  :adapter  => 'oracle',
  :username => ENV["ORACLE_USER"] || 'blog',
  :password => ENV["ORACLE_PASS"] || 'blog',
  :host => ENV["ORACLE_HOST"] || 'localhost',
  :database => ENV["ORACLE_SID"] || 'XE',
  # :statement_escape_processing => true, # set by default on AR >= 4.0
  :prepared_statements => ENV['PREPARED_STATEMENTS'] || ENV['PS']
}
config[:insert_returning] = ENV['INSERT_RETURNING'] if ENV['INSERT_RETURNING']

require 'jdbc/oracle'
# Download JDBC driver from :
# http://www.oracle.com/technetwork/database/features/jdbc/index-091264.html
#
# NOTE: if you're seeing the following error on XML column test(s) :
#
#   Java::JavaLang::NoClassDefFoundError: oracle/xml/binxml/BinXMLException
#
# Make sure you have the optional JARs on the CP e.g. under _test/jars_
#
# Also a recent parser JAR is needed: _xmlparserv2.jar_ which seems "hard" to
# get (hey it's an oracle you're supposed to know :)), download JDeveloper
#
# http://schoudari.wordpress.com/2011/12/08/java-spring-oracle-inserting-xmltype-2/
#
# Now that you got it it has to match the version with the *xdb.jar* or YAYY :
#
#   Java::JavaLang::IllegalAccessError: tried to access class
#   oracle.xml.binxml.BinXMLDecoderImpl from class oracle.xdb.XMLType
#
# Thus, it's likely best to get all JDBC jars from your Oracle installation ...
# http://www.oracle.com/technetwork/database/enterprise-edition/databaseappdev-vm-161299.html
begin
  silence_warnings { Java::JavaClass.for_name(Jdbc::Oracle.driver_name) }
rescue NameError
  begin
    Jdbc::Oracle.load_driver
  rescue LoadError => e
    warn "Please setup a JDBC driver to run the Oracle tests !"
    raise e
  end
end

ActiveRecord::Base.establish_connection(config)
