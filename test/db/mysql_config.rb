MYSQL_CONFIG = {
  :username => 'arjdbc',
  :password => 'arjdbc',
  :adapter  => 'mysql2',
  :database => 'arjdbc_test',
  :host     => 'localhost'
}

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  MYSQL_CONFIG[:prepared_statements] = ps
end

if driver = ENV['DRIVER']
  if driver =~ /maria/i
    if driver.index('.').nil?
      driver = 'org.mariadb.jdbc.Driver'
    end
    jars = File.expand_path('../jars', File.dirname(__FILE__))
    if jar = Dir.glob("#{jars}/mariadb*.jar").last
      load jar
    end
  end
  MYSQL_CONFIG[:driver] = driver if driver.index('.')
end