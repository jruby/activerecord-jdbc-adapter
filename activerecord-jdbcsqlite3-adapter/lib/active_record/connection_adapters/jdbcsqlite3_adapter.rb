# NOTE: required by AR resolver with 'jdbcsqlite3' adapter configuration :
# require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
# we should make sure a jdbcsqlite3_connection is setup on ActiveRecord::Base
require 'arjdbc/sqlite3'
# all setup should be performed in arjdbc/sqlite3 to avoid circular requires
# this should not be required from any loads perormed by arjdbc/sqlite3 code