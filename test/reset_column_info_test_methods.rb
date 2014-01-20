module ResetColumnInfoTestMethods

  class Fhqwhgad < ActiveRecord::Base; end

  def test_reset_column_information
    drop_fhqwhgads_table!
    create_fhqwhgads_table_1!
    Fhqwhgad.reset_column_information
    assert_equal ["id", "come_on"].sort, Fhqwhgad.columns.map{|c| c.name}.sort, "columns should be correct the first time"

    drop_fhqwhgads_table!
    create_fhqwhgads_table_2!
    Fhqwhgad.reset_column_information
    assert_equal ["id", "to_the_limit"].sort, Fhqwhgad.columns.map{|c| c.name}.sort, "columns should be correct the second time"
  ensure
    drop_fhqwhgads_table!
  end

  private

  def drop_fhqwhgads_table!
    ActiveRecord::Schema.define do
      suppress_messages do
        drop_table :fhqwhgads if table_exists? :fhqwhgads
      end
    end
  end

  def create_fhqwhgads_table_1!
    ActiveRecord::Schema.define do
      suppress_messages do
        create_table :fhqwhgads do |t|
          t.string :come_on
        end
      end
    end
  end

  def create_fhqwhgads_table_2!
    ActiveRecord::Schema.define do
      suppress_messages do
        create_table :fhqwhgads do |t|
          t.string :to_the_limit, :null=>false, :default=>'everybody'
        end
      end
    end
  end

end
ResetColumnInformationTestMethods = ResetColumnInfoTestMethods