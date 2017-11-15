class DbTypeMigration < ActiveRecord::Migration[4.2]
  
  # Oracle/SQLServer supports precision up to 38
  @@big_decimal_precision = 38
  
  def self.big_decimal_precision; @@big_decimal_precision; end
  def self.big_decimal_precision=(precision); @@big_decimal_precision = precision; end
  
  def self.up
    create_table "db_types", :force => true do |t|
      t.column :sample_timestamp, :timestamp
      t.column :sample_datetime, :datetime
      t.column :sample_date, :date
      t.column :sample_time, :time
      # NOTE: on purpose setup so that it's OK to use a 32-bit integer column :
      t.column :sample_decimal, :decimal, :precision => 9, :scale => 0
      t.column :sample_small_decimal, :decimal, :precision => 3, :scale => 2, :default => 3.14
      t.column :sample_default_decimal, :decimal
      t.column :sample_float, :float
      t.column :sample_binary, :binary
      t.column :sample_boolean, :boolean
      t.column :sample_string, :string, :default => ''
      t.column :sample_integer, :integer, :limit => 5
      t.column :sample_integer_with_limit_2, :integer, :limit => 2
      t.column :sample_integer_with_limit_8, :integer, :limit => 8
      t.column :sample_integer_no_limit, :integer, :default => 42
      t.column :sample_integer_neg_default, :integer, :default => -1
      t.column :sample_text, :text
      t.decimal :decimal_with_scale, :precision => 15, :scale => 3
      t.decimal :big_decimal, :precision => big_decimal_precision, :scale => 0
    end
  end

  def self.down
    drop_table "db_types"
  end
end

class DbType < ActiveRecord::Base
end
