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
  
  create_table :authors do |t|
    t.column :name, :string, :null => false
  end
  
  add_index :authors, :name, :unique
end

class Author < ActiveRecord::Base; end

1.times do 
  $stderr.print '.'
  Author.destroy_all
  Author.create(:name => "Arne Svensson")
  Author.create(:name => "Pelle Gogolsson")

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
