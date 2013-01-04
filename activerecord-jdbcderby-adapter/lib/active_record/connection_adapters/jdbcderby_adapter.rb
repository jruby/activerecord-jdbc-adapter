# NOTE: required by AR resolver with 'jdbcderby' adapter configuration :
# we should make sure a jdbcderby_connection is setup on ActiveRecord::Base
require 'arjdbc/derby'
# all setup should be performed in arjdbc/derby to avoid circular requires
# this should not be required from any loads perormed by arjdbc/derby code