config = {
  :username   => 'blog',
  :password   => 'blog',
  :adapter    => 'informix',
  :servername => 'ol_weblog',
  :database   => 'weblog_development',
  :host       => 'localhost',
  :port       => '9088'
}

ActiveRecord::Base.establish_connection(config)
