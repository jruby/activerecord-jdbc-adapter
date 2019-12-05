# -*- encoding : utf-8 -*-

require File.expand_path('test_helper', File.dirname(__FILE__))

class MySQLRailsTest < Test::Unit::TestCase


  class Weird < ActiveRecord::Base; end

  test 'BasicsTest#test_unicode_column_name' do
    begin

      connection.create_table :weirds, force: true do |t|
        t.string 'a$b'
        t.string 'なまえ'
        t.string 'from'
      end

      # test
      Weird.reset_column_information
      weird = Weird.create(:なまえ => 'たこ焼き仮面')
      assert_equal 'たこ焼き仮面', weird.なまえ

    ensure
      connection.drop_table(:weirds) rescue nil
    end
  end


  class Binary < ActiveRecord::Base; end

  test 'BinaryTest#test_mixed_encoding:' do
    begin

      create_table :binaries, force: true do |t|
        t.string :name
        t.binary :data
        t.binary :short_data, limit: 2048
      end

      # test
      str = "\x80"
      str.force_encoding('ASCII-8BIT')

      binary = Binary.new :name => 'いただきます！', :data => str
      binary.save!
      binary.reload
      assert_equal str, binary.data

      name = binary.name

      assert_equal 'いただきます！', name

    ensure
      drop_table(:binaries) rescue nil
    end
  end


  class Mentor < ActiveRecord::Base
    has_many :developers
  end

  class Developer < ActiveRecord::Base
    self.ignored_columns = %w(first_name last_name)

    has_and_belongs_to_many :projects do
      def find_most_recent
        order("id DESC").first
      end
    end

    # accepts_nested_attributes_for :projects

    belongs_to :mentor

    has_many :contracts

    has_many :contracted_projects, class_name: "Project"

    validates_inclusion_of :salary, :in => 50000..200000
    validates_length_of    :name, :within => 3..20

    attr_accessor :last_name
    define_attribute_method 'last_name'

  end

  class Contract < ActiveRecord::Base
    belongs_to :company
    belongs_to :developer
  end

  class Project < ActiveRecord::Base
    belongs_to :mentor
    has_and_belongs_to_many :developers, -> { distinct.order 'developers.name desc, developers.id desc' }
  end

  test 'EagerAssociationTest#test_eager_load_multiple_associations_with_references:' do
    begin

      create_table :contracts, force: true do |t|
        t.integer :developer_id
        t.integer :company_id
      end

      create_table :developers, force: true do |t|
        t.string   :name
        t.string   :first_name
        t.integer  :salary, default: 70000
        t.integer  :mentor_id

        t.datetime :created_at
        t.datetime :updated_at
      end

      create_table :mentors, force: true do |t|
        t.string :name
      end

      create_table :projects, force: true do |t|
        t.string :name
        t.string :type
        t.integer :mentor_id
      end

      create_table :developers_projects, force: true, id: false do |t|
        t.integer :developer_id, null: false
        t.integer :project_id, null: false
        t.date    :joined_on
        t.integer :access_level, default: 1
      end

      # test_eager_load_multiple_associations_with_references
      mentor = Mentor.create!(name: "Barış Can DAYLIK")
      developer = Developer.create!(name: "Mehmet Emin İNAÇ", mentor: mentor)
      Contract.create!(developer: developer)
      project = Project.create!(name: "VNGRS", mentor: mentor)
      project.developers << developer
      projects = Project.references(:mentors).includes(mentor: { developers: :contracts }, developers: :contracts)
      assert_equal projects.last.mentor.developers.first.contracts, projects.last.developers.last.contracts

    ensure
      [ :contracts, :developers, :mentors, :projects, :developers_projects ].each { |table| drop_table(table) rescue nil }
    end
  end


  class Car < ActiveRecord::Base
    has_many :bulbs
    has_many :all_bulbs, -> { unscope where: :name }, class_name: "Bulb"
  end

  class Bulb < ActiveRecord::Base
    default_scope { where(:name => 'defaulty') }
    belongs_to :car, :touch => true
    scope :awesome, -> { where(frickinawesome: true) }
  end

  test 'HasManyAssociationsTest#test_ids_reader_memoization:' do
    begin

      create_table :cars, force: true do |t|
        t.string  :name
        t.integer :engines_count
        t.integer :wheels_count
        t.column :lock_version, :integer, null: false, default: 0
        t.timestamps null: false
      end

      create_table :bulbs, force: true do |t|
        t.integer :car_id
        t.string  :name
        t.boolean :frickinawesome, default: false
        t.string :color
      end

      # test_ids_reader_memoization
      car = Car.create!(name: 'Tofaş')
      bulb = Bulb.create!(car: car)

      assert_equal [ bulb.id ], car.bulb_ids
      assert_no_queries { car.bulb_ids }

    ensure
      [ :bulbs, :cars ].each { |table| drop_table(table) rescue nil }
    end
  end


  class Topic < ActiveRecord::Base

    serialize :content
    alias_attribute :heading, :title

    def parent
      Topic.find(parent_id)
    end

  end

  test 'UniquenessValidationTest#test_validate_case_insensitive_uniqueness:' do
    begin

      create_table :topics, force: true do |t|
        t.string   :title, limit: 250
        t.datetime :written_on
        t.boolean  :approved, default: true
        t.string   :content, limit: 4000
        t.string   :important, limit: 4000
        t.integer  :parent_id
        t.string   :type
      end

      # test_validate_case_insensitive_uniqueness
      Topic.validates_uniqueness_of(:title, :parent_id, :case_sensitive => false, :allow_nil => true)

      t = Topic.new("title" => "I'm unique!", :parent_id => 1)
      assert t.save, "Should save t as unique"

      t.content = "Remaining unique"
      assert t.save, "Should still save t as unique"

      t2 = Topic.new("title" => "I'm UNIQUE!", :parent_id => 1)
      assert !t2.valid?, "Shouldn't be valid"
      assert !t2.save, "Shouldn't save t2 as unique"

      assert t2.errors[:title].any?
      assert t2.errors[:parent_id].any?
      assert_equal ["has already been taken"], t2.errors[:title]

      t2.title = "I'm truly UNIQUE!"
      assert !t2.valid?, "Shouldn't be valid"
      assert !t2.save, "Shouldn't save t2 as unique"
      assert t2.errors[:title].empty?
      assert t2.errors[:parent_id].any?

      t2.parent_id = 4
      assert t2.save, "Should now save t2 as unique"

      t2.parent_id = nil
      t2.title = nil
      assert t2.valid?, "should validate with nil"
      assert t2.save, "should save with nil"

      t_utf8 = Topic.new("title" => "Я тоже уникальный!")
      assert t_utf8.save, "Should save t_utf8 as unique"

      # If database hasn't UTF-8 character set, this test fails
      if Topic.all.merge!(:select => 'LOWER(title) AS title').find(t_utf8.id).title == "я тоже уникальный!"
        t2_utf8 = Topic.new("title" => "я тоже УНИКАЛЬНЫЙ!")
        assert !t2_utf8.valid?, "Shouldn't be valid"
        assert !t2_utf8.save, "Shouldn't save t2_utf8 as unique"
      end

    ensure
      [ :topics ].each { |table| drop_table(table) rescue nil }
    end
  end


  class Event < ActiveRecord::Base
    validates_uniqueness_of :title, case_sensitive: true
  end

  test 'UniquenessValidationTest#test_validate_uniqueness_with_limit_and_utf8' do
    begin

      create_table :events, force: true do |t|
        t.string :title, limit: 5
      end

      # test_validate_uniqueness_with_limit_and_utf8
      assert_raise(ActiveRecord::ValueTooLong) do
        Event.create(title: "一二三四五六七八")
      end

    ensure
      [ :events ].each { |table| drop_table(table) rescue nil }
    end
  end


  private

  delegate :create_table, :drop_table, to: :connection

end
