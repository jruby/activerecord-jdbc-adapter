# Simple method to reduce the boilerplate
def jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
end

require 'bundler'
Bundler.require(:default, :test)
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
require 'minitest/unit'
require 'logger'

# we always require logger (some tests fail if ActiveRecord::Base.logger is nil), but level
# is set to warn unless $DEBUG or ENV['DEBUG'] is set
require 'db/logger'
if $DEBUG || ENV['DEBUG']
  require 'ruby-debug'
else
end


