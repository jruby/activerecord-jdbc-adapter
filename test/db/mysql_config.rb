MYSQL_CONFIG = {
  :username => 'root',
  :password => '',
  :adapter  => 'mysql2',
  :database => 'arjdbc_test',
  :host     => 'localhost'
}

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  MYSQL_CONFIG[:prepared_statements] = ps
end

if driver = ENV['DRIVER']
  if driver =~ /maria/i
    driver = 'org.mariadb.jdbc.Driver' if driver.index('.').nil?
    $LOAD_PATH << File.expand_path('../../../jdbc-mariadb/lib', __FILE__)
    require 'jdbc/mariadb'; Jdbc::MariaDB.load_driver
  end
  MYSQL_CONFIG[:driver] = driver if driver.index('.')
else
  # detect rake test_mariadb when "jdbc-mariadb/lib" is on the load-path :
  if $LOAD_PATH.find { |path| path =~ /jdbc\-mariadb\/lib$/ }
    MYSQL_CONFIG[:adapter] = 'mariadb'
    #MYSQL_CONFIG[:driver] = 'org.mariadb.jdbc.Driver'
  end
end