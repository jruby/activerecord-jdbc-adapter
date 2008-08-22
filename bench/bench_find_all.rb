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
require 'rubygems'
require 'active_record'
require 'benchmark'

is_jruby = defined? RUBY_ENGINE && RUBY_ENGINE == "jruby"

ActiveRecord::Base.establish_connection(
  :adapter => is_jruby ? "jdbcmysql" : "mysql",
  :host => "localhost",
  :username => "root",
  :database => "ar_bench"
)

class Widget < ActiveRecord::Base; end

ActiveRecord::Base.logger = Logger.new(File.expand_path(File.dirname(__FILE__) + "/database.log"))

TIMES = (ARGV[0] || 5).to_i
Benchmark.bm do |make|
  TIMES.times do
    make.report do
      10_000.times do
        Widget.find(:all)
      end
    end
  end
end
