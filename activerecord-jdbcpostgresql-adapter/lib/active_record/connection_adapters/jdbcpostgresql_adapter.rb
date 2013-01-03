# NOTE: required by AR resolver with 'jdbcpostgresql' adapter configuration :
# require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
# we should make sure a jdbcpostgresql_connection is setup on ActiveRecord::Base
require 'arjdbc/postgresql'
# all setup should be performed in arjdbc/postgresql to avoid circular requires
# this should not be required from any loads perormed by arjdbc/postgresql code