# NOTE: here for Bundler to auto-load the gem unless :require => false
require 'arjdbc' 
# ArJdbc loads arjdbc/sqlite3 eagerly to override Rails' native adapter thus 
# this will work even if `adapter: sqlite3` specified - but just in case :
require 'arjdbc/sqlite3'