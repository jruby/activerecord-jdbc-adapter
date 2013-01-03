# NOTE: required by AR resolver with 'jdbch2' adapter configuration :
# we should make sure a jdbch3_connection is setup on ActiveRecord::Base
require 'arjdbc/h2'
# all setup should be performed in arjdbc/h2 to avoid circular requires
# this should not be required from any loads perormed by arjdbc/h2 code