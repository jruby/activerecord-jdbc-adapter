# NOTE: here for Bundler to auto-load the gem unless :require => false
require 'arjdbc' 
# ArJdbc loads arjdbc/postgresql eagerly to override Rails' native adapter thus 
# this will work even if `adapter: postgresql` specified - but just in case :
require 'arjdbc/postgresql'