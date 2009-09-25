require 'jdbc_common'
require 'db/sqlite3'
require 'models/data_types'
require 'models/validates_uniqueness_of_string'

class SQLite3SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  
  def test_recreate_database
    assert @connection.tables.include?(Entry.table_name)
    db = @connection.database_name
    @connection.recreate_database(db)
    assert (not @connection.tables.include? Entry.table_name)
    self.setup # avoid teardown complaining
  end
  
  def test_execute_insert
    assert_equal 1, Entry.count
    id = @connection.execute "INSERT INTO entries (title, content) VALUES ('Execute Insert', 'This now works with SQLite3')"
    assert_equal Entry.last.id, id
    assert_equal 2, Entry.count
  end
  
  def test_execute_update
    affected_rows = @connection.execute "UPDATE entries SET title = 'Execute Update' WHERE id = #{Entry.first.id}"
    assert_equal 1, affected_rows    
    assert_equal 'Execute Update', Entry.first.title
  end
  
  def test_columns
    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "title"}
  end
  
  def test_remove_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_remove_column", :string
      end
    end
    
    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "test_remove_column"}
    
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        remove_column "entries", "test_remove_column"
      end
    end
    
    cols = ActiveRecord::Base.connection.columns("entries")
    assert !cols.find {|col| col.name == "test_remove_column"}
  end
  
  def test_rename_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "title", "name"
      end
    end
      
    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "name"}
    assert !cols.find {|col| col.name == "title"}
    
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "name", "title"
      end
    end
      
    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "title"}
    assert !cols.find {|col| col.name == "name"}
  end
  
  def test_change_column_default
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_change_column_default", :string, :default => "unchanged"
      end
    end
    
    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_change_column_default"}
    assert col
    assert_equal col.default, 'unchanged'
    
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        change_column_default "entries", "test_change_column_default", "changed"
      end
    end
    
    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_change_column_default"}
    assert col
    assert_equal col.default, 'changed'
  end
  
  def test_change_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_change_column", :string
      end
    end
      
    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_change_column"}
    assert col
    assert_equal col.type, :string
    
    assert_nothing_raised do  
      ActiveRecord::Schema.define do
        change_column "entries", "test_change_column", :integer
      end
    end
    
    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_change_column"}
    assert col
    assert_equal col.type, :integer
  end
  
end

class SQLite3ValidatesUniquenessOfStringsTest < Test::Unit::TestCase
  def setup
    CreateValidatesUniquenessOfStrings.up
  end
  def teardown
    CreateValidatesUniquenessOfStrings.down
  end

  def test_validates_uniqueness_of_strings_case_sensitive
    name_lower = ValidatesUniquenessOfString.new(:case_sensitive_string => "name", :case_insensitive_string => '1')
    name_lower.save!
    
    name_upper = ValidatesUniquenessOfString.new(:case_sensitive_string => "NAME", :case_insensitive_string => '2')
    assert_nothing_raised do
      name_upper.save!
    end
    
    name_lower_collision = ValidatesUniquenessOfString.new(:case_sensitive_string => "name", :case_insensitive_string => '3')
    assert_raise ActiveRecord::RecordInvalid do
      name_lower_collision.save!
    end
    
    name_upper_collision = ValidatesUniquenessOfString.new(:case_sensitive_string => "NAME", :case_insensitive_string => '4')
    assert_raise ActiveRecord::RecordInvalid do
      name_upper_collision.save!
    end
  end
  
  def test_validates_uniqueness_of_strings_case_insensitive
    name_lower = ValidatesUniquenessOfString.new(:case_sensitive_string => '1', :case_insensitive_string => "name")
    name_lower.save!
    
    name_upper = ValidatesUniquenessOfString.new(:case_sensitive_string => '2', :case_insensitive_string => "NAME")
    assert_raise ActiveRecord::RecordInvalid do
      name_upper.save!
    end
    
    name_lower_collision = ValidatesUniquenessOfString.new(:case_sensitive_string => '3', :case_insensitive_string => "name")
    assert_raise ActiveRecord::RecordInvalid do
      name_lower_collision.save!
    end
    
    alternate_name_upper = ValidatesUniquenessOfString.new(:case_sensitive_string => '4', :case_insensitive_string => "ALTERNATE_NAME")
    assert_nothing_raised do
      alternate_name_upper.save!
    end
    
    alternate_name_upper_collision = ValidatesUniquenessOfString.new(:case_sensitive_string => '5', :case_insensitive_string => "ALTERNATE_NAME")
    assert_raise ActiveRecord::RecordInvalid do
      alternate_name_upper_collision.save!
    end
    
    alternate_name_lower = ValidatesUniquenessOfString.new(:case_sensitive_string => '6', :case_insensitive_string => "alternate_name")
    assert_raise ActiveRecord::RecordInvalid do
      alternate_name_lower.save!
    end
  end
end

# assert_raise ActiveRecord::RecordInvalid do
  
class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end

if jruby?
  JInteger = java.lang.Integer
else
  JInteger = Fixnum
  class Fixnum
    # Arbitrary value...we could pick 
    MAX_VALUE = 2
  end
end

class SQLite3TypeConversionTest < Test::Unit::TestCase
  TEST_TIME = Time.at(1169964202)
  TEST_BINARY = "Some random binary data % \0 and then some"
  def setup
    DbTypeMigration.up  
    DbType.create(
      :sample_timestamp => TEST_TIME,
      :sample_datetime => TEST_TIME,
      :sample_time => TEST_TIME,
      :sample_date => TEST_TIME,
      :sample_decimal => JInteger::MAX_VALUE + 1,
      :sample_small_decimal => 3.14,
      :sample_binary => TEST_BINARY)
  end

  def teardown
    DbTypeMigration.down
  end

  def test_decimal
    types = DbType.find(:first)
    assert_equal((JInteger::MAX_VALUE + 1), types.sample_decimal)
  end

  def test_decimal_scale
    types = DbType.find(:first)
    assert_equal(2, DbType.columns_hash["sample_small_decimal"].scale)
  end

  def test_decimal_precision
    types = DbType.find(:first)
    assert_equal(3, DbType.columns_hash["sample_small_decimal"].precision)
  end
  
  def test_binary
    types = DbType.find(:first)
    assert_equal(TEST_BINARY, types.sample_binary)
  end

end
