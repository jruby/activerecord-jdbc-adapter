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
  drop_table :author rescue nil
  
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

  change_column :author, :descr, :string, :limit => 100 if /db2|derby/ !~ ARGV[1]
  change_column_default :author, :female, false if /db2|derby|mssql|firebird/ !~ ARGV[1]
  remove_column :author, :died if /db2|derby/ !~ ARGV[1]
  rename_column :author, :wakeup_time, :waking_time if /db2|derby|mimer/ !~ ARGV[1]
 
  add_index :author, :name, :unique if /db2/ !~ ARGV[1]
  add_index :author, [:age,:female], :name => :is_age_female if /db2/ !~ ARGV[1]
 
  remove_index :author, :name if /db2/ !~ ARGV[1]
  remove_index :author, :name => :is_age_female if /db2/ !~ ARGV[1]
  
  rename_table :author, :authors if /db2|firebird|mimer/ !~ ARGV[1]


    create_table :products, :force => true do |t|
      t.column :title,       :string
      t.column :description, :text
      t.column :image_url,   :string
    end
    add_column :products, :price, :float, :default => 0.0
    create_table :orders, :force => true do |t|
      t.column :name, :string
      t.column :address, :text
      t.column :email, :string
      t.column :pay_type, :string, :limit => 10
    end
    create_table :line_items, :force => true do |t|
      t.column :product_id,  :integer, :null => false
      t.column :order_id,    :integer, :null => false
      t.column :quantity,    :integer, :null => false
      t.column :total_price, :float, :null => false
    end
end

class Author < ActiveRecord::Base;
  set_table_name "author" if /db2|firebird|mimer/ =~ ARGV[1]
end

class Order < ActiveRecord::Base
  has_many :line_items
end

class Product < ActiveRecord::Base
  has_many :orders, :through => :line_items
  has_many :line_items
  
  def self.find_products_for_sale
    find(:all, :order => "title")
  end
end

class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
end

    Product.create(:title => 'Pragmatic Project Automation',
    :description => 
    %{<p>
       <em>Pragmatic Project Automation</em> shows you how to improve the 
       consistency and repeatability of your project's procedures using 
       automation to reduce risk and errors.
      </p>
      <p>
        Simply put, we're going to put this thing called a computer to work 
        for you doing the mundane (but important) project stuff. That means 
        you'll have more time and energy to do the really 
        exciting---and difficult---stuff, like writing quality code.
      </p>},
    :image_url =>   '/images/auto.jpg',    
    :price => 29.95)


    Product.create(:title => 'Pragmatic Version Control',
      :description =>
      %{<p>
         This book is a recipe-based approach to using Subversion that will 
         get you up and 
         running quickly---and correctly. All projects need version control: 
         it's a foundational piece of any project's infrastructure. Yet half 
         of all project teams in the U.S. don't use any version control at all. 
         Many others don't use it well, and end up experiencing time-consuming problems.
      </p>},
    :image_url => '/images/svn.jpg',
    :price => 28.50)
    
    # . . .


    Product.create(:title => 'Pragmatic Unit Testing (C#)',
    :description => 
    %{<p>
        Pragmatic programmers use feedback to drive their development and 
        personal processes. The most valuable feedback you can get while 
        coding comes from unit testing.
      </p>
      <p>
        Without good tests in place, coding can become a frustrating game of 
        "whack-a-mole." That's the carnival game where the player strikes at a 
        mechanical mole; it retreats and another mole pops up on the opposite side 
        of the field. The moles pop up and down so fast that you end up flailing 
        your mallet helplessly as the moles continue to pop up where you least 
        expect them.
      </p>},
    :image_url => '/images/utc.jpg',
    :price => 27.75)




1.times do 
  $stderr.print '.'
  Author.destroy_all
  Author.create(:name => "Arne Svensson", :age => 30)
  if /db2|derby|mimer/ !~ ARGV[1]
    Author.create(:name => "Pelle Gogolsson", :age => 15, :waking_time => Time.now, :private_key => "afbafddsfgsdfg")
  else
    Author.create(:name => "Pelle Gogolsson", :age => 15, :wakeup_time => Time.now, :private_key => "afbafddsfgsdfg")
  end
  Author.find(:first)
  Author.find(:all)
  arne = Author.find(:first)
  arne.destroy

  pelle = Author.find(:first)
  pelle.name = "Pelle Sweitchon"
  pelle.description = "dfsssdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
  pelle.descr = "adsfasdf"
  pelle.age = 79
  pelle.weight = 57.6
  pelle.born = Time.gm(1982,8,13,10,15,3,0)
  pelle.female = false
  pelle.save

  prods = Product.find :all
  order = Order.new(:name => "Dalai Lama", :address => "Great Road 32", :email => "abc@dot.com", :pay_type => "cash")
  order.line_items << LineItem.new(:product => prods[0], :quantity => 3, :total_price => (prods[0].price * 3))
  order.line_items << LineItem.new(:product => prods[2], :quantity => 1, :total_price => (prods[2].price))
  order.save

  puts "order: #{order.line_items.inspect}, with id: #{order.id} and name: #{order.name}"
end

ActiveRecord::Schema.define do 
    drop_table :line_items
    drop_table :orders
    drop_table :products

  
  drop_table((/db2|firebird|mimer/=~ARGV[1]? :author : :authors ))
end
