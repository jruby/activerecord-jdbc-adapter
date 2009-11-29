=begin

* This scripts looks for an optional argv0 which is number of times to
  execute the particular benchmark this file is getting required into. argv1
  is an optional parameter which represents the number of rows to create.
* Use ENV['LOGGER'] (=severe|warn|info|debug) to turn on the logger
* Add ActiveRecord to load path to use a specific (non-gem version) for testing (e.g., edge).

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

TIMES = (ARGV[0] || 5).to_i
ROW_COUNT = (ARGV[1] || 10).to_i

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

if defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
  $LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
  $LOAD_PATH.unshift File.dirname(__FILE__) + '/../drivers/mysql/lib'
  $LOAD_PATH.unshift File.dirname(__FILE__) + '/../adapters/mysql/lib'
  require 'active_record/connection_adapters/jdbcmysql_adapter'
end

if ENV['LOGGER']
  require 'logger'
  ActiveRecord::Base.logger = Logger.new(File.expand_path(File.dirname(__FILE__) + "/debug.log"))
  lvl = %(DEBUG INFO WARN ERROR FATAL).detect {|s| s =~ /#{ENV['LOGGER'].upcase}/}
  ActiveRecord::Base.logger.level = lvl && Logger.const_get(lvl) || Logger::INFO
else
  ActiveRecord::Base.logger = Logger.new($stdout)
  ActiveRecord::Base.logger.level = Logger::UNKNOWN
end

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
Widget.destroy_all if Widget.count > ROW_COUNT
count = Widget.count
while (count < ROW_COUNT)
  Widget.create!(:name => "bench#{count}", :description => "Bench record#{count}")
  count = Widget.count
end

ActiveRecord::Base.clear_active_connections!
