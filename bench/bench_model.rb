=begin
+----------+------+-----+---------+-----------------+----------------+
| Field       | Type         | Null | Key | Default | Extra          |
+-------------+--------------+------+-----+---------+----------------+
| id          | int(11)      | NO   | PRI | NULL    | auto_increment |
| name        | varchar(255) | YES  |     | NULL    |                |
| description | text         | YES  |     | NULL    |                |
| created_at  | datetime     | YES  |     | NULL    |                |
| updated_at  | datetime     | YES  |     | NULL    |                |
+-------------+--------------+------+-----+---------+----------------+
=end

ENV["RAILS_ENV"] = "production"
begin
  print "Loading ActiveRecord w/o gems..."
  require 'active_record'
  require 'active_record/version'
  puts "version #{ActiveRecord::VERSION::STRING}"
rescue LoadError
  puts "FAILED."
  print "Loading ActiveRecord with gems..."
  require 'rubygems'
  gem 'activerecord'
  puts "version #{Gem.loaded_specs['activerecord'].version.version}"
  require 'active_record'
end
require 'benchmark'

if defined? RUBY_ENGINE && RUBY_ENGINE == "jruby"
  $LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
  $LOAD_PATH.unshift File.dirname(__FILE__) + '/../drivers/mysql/lib'
  $LOAD_PATH.unshift File.dirname(__FILE__) + '/../adapters/mysql/lib'
  require 'active_record/connection_adapters/jdbcmysql_adapter'
end

require 'logger'
ActiveRecord::Base.logger = Logger.new(File.expand_path(File.dirname(__FILE__) + "/debug.log"))

ActiveRecord::Base.establish_connection(
  :adapter => "mysql",
  :host => "localhost",
  :username => "root",
  :database => "ar_bench",
  :pool => 10,
  :wait_timeout => 0.5
)

class CreateWidgets < ActiveRecord::Migration
  def self.up
    create_table :widgets do |t|
      t.string :name
      t.text :description
      t.timestamps
    end
  end
end

CreateWidgets.up unless ActiveRecord::Base.connection.tables.include?("widgets")

class Widget < ActiveRecord::Base; end

ActiveRecord::Base.clear_active_connections!
