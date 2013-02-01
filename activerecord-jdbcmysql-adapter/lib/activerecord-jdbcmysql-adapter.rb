# NOTE: here for Bundler to auto-load the gem unless :require => false
require 'arjdbc'
# ArJdbc loads arjdbc/mysql eagerly to override Rails' native adapter thus 
# this will work even if `adapter: mysql2` specified - but just in case :
require 'arjdbc/mysql'