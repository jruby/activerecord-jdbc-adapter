# NOTE: required by AR resolver with 'jdbcas400' adapter configuration :
# we should make sure a jdbcdb2_connection is setup on ActiveRecord::Base
require 'arjdbc/db2'
require 'arjdbc/db2/as400'
# all setup should be performed in arjdbc/db2 to avoid circular requires
# this should not be required from any loads perormed by arjdbc/db2 code