MYSQL_CONFIG = {
  username:  'arjdbc',
  password:  'arjdbc',
  adapter:   'mysql2',
  database:  'arjdbc_test',
  host:      'localhost',
  encoding:  'utf8',
  collation: 'utf8_general_ci'
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
end

if defined? JRUBY_VERSION
  MYSQL_CONFIG[:properties] ||= {}
  MYSQL_CONFIG[:properties]['cacheDefaultTimezone'] = false
  MYSQL_CONFIG[:properties]['serverTimezone'] = java.util.TimeZone.getDefault.getID
  MYSQL_CONFIG[:properties]['allowPublicKeyRetrieval'] = true
end

