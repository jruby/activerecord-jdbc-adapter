# Simple method to reduce the boilerplate
def jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
end

require 'arjdbc' if jruby?
puts "Using activerecord version #{ActiveRecord::VERSION::STRING}"
require 'models/auto_id'
require 'models/entry'
require 'models/data_types'
require 'models/add_not_null_column_to_table'
require 'models/validates_uniqueness_of_string'
require 'models/string_id'
require 'models/thing'
require 'models/custom_pk_name'
require 'simple'
require 'has_many_through'
require 'helper'
require 'row_locking'
require 'test/unit'

# Comment/uncomment to enable logging to be loaded for any of the database adapters
if $DEBUG || ENV['DEBUG']
  require 'db/logger'
  require 'ruby-debug'
end


