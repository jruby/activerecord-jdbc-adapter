config = { 
  :username => 'blog',
  :password => '',
  :adapter  => 'jdbc',
  :url => "jdbc:jtds:sqlserver://localhost:1433/weblog_development",
  :driver => 'net.sourceforge.jtds.jdbc.Driver'
}

ActiveRecord::Base.establish_connection( config )
