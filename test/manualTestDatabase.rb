#!/usr/bin/env jruby

if ARGV.length < 2  
  $stderr.puts "syntax: #{__FILE__} [filename] [configuration-name]"
  $stderr.puts "  where filename points to a YAML database configuration file"
  $stderr.puts "  and the configuration name is in this file"
  exit
end

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'yaml'
require 'rubygems'
RAILS_CONNECTION_ADAPTERS = ['mysql', 'jdbc']
require 'active_record'

cfg = (File.open(ARGV[0]) {|f| YAML.load(f) })[ARGV[1]]

ActiveRecord::Base.establish_connection(cfg)

ActiveRecord::Schema.define do
  drop_table :authors rescue nil
  
  create_table :author, :force => true do |t|
    t.column :name, :string, :null => false
  end

  # Exercise all types, and add_column
  add_column :author, :description, :text
  add_column :author, :descr, :string, :limit => 50
  add_column :author, :age, :integer, :null => false, :default => 17
  add_column :author, :weight, :float
  add_column :author, :born, :datetime
  add_column :author, :died, :timestamp
  add_column :author, :wakeup_time, :time
  add_column :author, :birth_date, :date
  add_column :author, :private_key, :binary
  add_column :author, :female, :boolean, :default => true

  change_column :author, :descr, :string, :limit => 100  #Only allow that much nonsense
#  change_column_default :author, :female, false
  remove_column :author, :died
  rename_column :author, :wakeup_time, :waking_time
  
  add_index :author, :name, :unique
  add_index :author, [:age,:female], :name => :is_age_female
  
  remove_index :author, :name
  remove_index :author, :name => :is_age_female
  
  rename_table :author, :authors
end

class Author < ActiveRecord::Base; end

1.times do 
  $stderr.print '.'
  Author.destroy_all
  Author.create(:name => "Arne Svensson", :age => 30)
  Author.create(:name => "Pelle Gogolsson", :age => 15)

  Author.find(:first)
  Author.find(:all)
  arne = Author.find(:first)
  arne.destroy

  pelle = Author.find(:first)
  pelle.name = "Pelle Sweitchon"
  pelle.save
end

ActiveRecord::Schema.define do 
  drop_table :authors
end
