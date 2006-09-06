# To run this script, run the following in a mysql instance:
#
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to blog@localhost;

require 'minirunit'

config = {
  :username => 'blog',
  :password => ''
}

if RUBY_PLATFORM =~ /java/
  RAILS_CONNECTION_ADAPTERS = ['abstract', 'jdbc']
  config.update({
    :adapter  => 'jdbc',
    :driver   => 'com.mysql.jdbc.Driver',
    :url      => 'jdbc:mysql://localhost:3306/weblog_development',
  })
else
  config.update({
    :adapter  => 'mysql',
    :database => 'weblog_development',
    :host     => 'localhost'
  })
end

require 'active_record'

ActiveRecord::Base.establish_connection(config)

class CreateEntries < ActiveRecord::Migration
  def self.up
    create_table "entries", :force => true do |t|
      t.column :title, :string, :limit => 100
      t.column :updated_on, :datetime
      t.column :content, :text
    end
  end

  def self.down
    drop_table "entries"
  end
end

CreateEntries.up

test_ok ActiveRecord::Base.connection.tables.include?('entries')

class Entry < ActiveRecord::Base
end

Entry.delete_all

test_equal 0, Entry.count

TITLE = "First post!"
CONTENT = "Hello from JRuby on Rails!"
NEW_TITLE = "First post updated title"

post = Entry.new
post.title = TITLE
post.content = CONTENT
post.save

test_equal 1, Entry.count

post = Entry.find(:first)
test_equal TITLE, post.title
test_equal CONTENT, post.content

post.title = NEW_TITLE
post.save

post = Entry.find(:first)
test_equal NEW_TITLE, post.title

post.destroy

test_equal 0, Entry.count

CreateEntries.down
