MYSQL_CONFIG = {
  :username => 'arjdbc',
  :password => 'arjdbc',
  :adapter  => 'mysql',
  :database => 'arjdbc_test',
  :host     => 'localhost'
}

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  MYSQL_CONFIG[:prepared_statements] = ps
end