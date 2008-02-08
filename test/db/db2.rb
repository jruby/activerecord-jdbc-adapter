config = {
  :username => "blog",
  :password => "",
  :adapter  => "jdbc",
  :driver => "com.ibm.db2.jcc.DB2Driver",
  :url => "jdbc:db2:weblog_development"
}

ActiveRecord::Base.establish_connection(config)
