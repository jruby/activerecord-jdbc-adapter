config = {
  :username => 'blog',
  :password => ''
}

if RUBY_PLATFORM =~ /java/
  config.update({
    :adapter  => 'jdbc',
    :driver   => 'com.mysql.jdbc.Driver',
    :url      => 'jdbc:mysql://localhost:3306/weblog_development',
  })
else
  config.update({
    :adapter  => 'mysql',
    :database => 'weblog_development',
    :host     => 'localhost'
  })
end

ActiveRecord::Base.establish_connection(config)
