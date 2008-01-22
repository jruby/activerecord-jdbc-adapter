config = {
  :username => 'blog',
  :password => '',
  :adapter  => 'oracle',
  :host => ENV["ORACLE_HOST"] || 'localhost',
  :database => ENV["ORACLE_SID"] || 'weblog_development'
}

ActiveRecord::Base.establish_connection(config)
