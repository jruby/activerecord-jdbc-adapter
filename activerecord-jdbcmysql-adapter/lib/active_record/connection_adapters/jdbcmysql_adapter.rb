# NOTE: required by AR resolver with 'jdbcmysql' adapter configuration :
# require "active_record/connection_adapters/#{spec[:adapter]}_adapter"
# we should make sure a jdbcmysql_connection is setup on ActiveRecord::Base
require 'arjdbc/mysql'
# all setup should be performed in arjdbc/mysql to avoid circular requires
# this should not be required from any loads perormed by arjdbc/mysql code