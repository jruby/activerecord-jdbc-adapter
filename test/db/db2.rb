config = {
# DB2 uses $USER if running locally, just add
# yourself to your db2 groups in /etc/group
#  :username => "blog",
#  :password => "",
  :adapter  => "jdbc",
  :driver => "com.ibm.db2.jcc.DB2Driver",
  :url => "jdbc:db2:weblog_development"
}

ActiveRecord::Base.establish_connection(config)
