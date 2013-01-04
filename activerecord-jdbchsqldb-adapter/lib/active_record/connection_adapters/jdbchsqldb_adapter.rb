# NOTE: required by AR resolver with 'jdbchsqldb' adapter configuration :
# we should make sure a jdbchsqldb_connection is setup on ActiveRecord::Base
require 'arjdbc/hsqldb'
# all setup should be performed in arjdbc/hsqldb to avoid circular requires
# this should not be required from any loads perormed by arjdbc/hsqldb code