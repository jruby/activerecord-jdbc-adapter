POSTGRES_CONFIG = {
  :adapter => 'postgresql',
  :database => 'arjdbc_test',
  :host => 'localhost',
  :username => 'arjdbc',
  :password => 'arjdbc',
  :connect_timeout => 10, # seconds
  :encoding => 'utf8',
  :collate => 'en_US.UTF-8',
}

POSTGRES_CONFIG[:host] = ENV['PGHOST'] if ENV['PGHOST']
POSTGRES_CONFIG[:port] = ENV['PGPORT'] if ENV['PGPORT']

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  POSTGRES_CONFIG[:prepared_statements] = ps
end

unless ( it = ENV['INSERT_RETURNING'] ).nil?
  POSTGRES_CONFIG[:insert_returning] = it
end
