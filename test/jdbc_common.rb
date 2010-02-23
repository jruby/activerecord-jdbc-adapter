# Simple method to reduce the boilerplate
def jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
end

require 'rubygems'
require 'pick_rails_version'
require 'jdbc_adapter' if jruby?
puts "Using activerecord version #{ActiveRecord::VERSION::STRING}"
puts "Specify version with AR_VERSION=={version} or RUBYLIB={path}"
require 'models/auto_id'
require 'models/entry'
require 'models/data_types'
require 'models/add_not_null_column_to_table'
require 'models/validates_uniqueness_of_string'
require 'models/string_id'
require 'simple'
require 'has_many_through'
require 'helper'
require 'test/unit'

# Comment/uncomment to enable logging to be loaded for any of the database adapters
# require 'db/logger'


