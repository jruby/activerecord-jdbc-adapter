# NOTE: required by AR resolver with 'jdbcmssql' adapter configuration :
# we should make sure a jdbcmssql_connection is setup on ActiveRecord::Base
require 'arjdbc/mssql'
# all setup should be performed in arjdbc/mssql to avoid circular requires
# this should not be required from any loads perormed by arjdbc/mssql code