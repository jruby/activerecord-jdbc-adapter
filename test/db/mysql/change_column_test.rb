require 'db/mysql'
require 'change_column_test_methods'

class MySQLChangeColumnTest < Test::Unit::TestCase
  include ChangeColumnTestMethods

  test 'change/rename text/binary column does not include default (strict mode)' do
    #ActiveRecord::Migration.add_column :people, :photo, :binary, :default => '0'
    #ActiveRecord::Migration.add_column :people, :about, :text, :default => ''
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge(:strict => false))

      ActiveRecord::Migration.add_column :people, :about, :string, :default => 'x'
      # NOTE: even in non strict mode MySQL does not allow us add or change
      # text/binary with a default ...
      ActiveRecord::Migration.change_column :people, :about, :text
      ActiveRecord::Migration.add_column :people, :photo, :binary
    end

    Person.reset_column_information

    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge(:strict => true))

      Person.connection.rename_column :people, :about, :desc
      Person.connection.rename_column :people, :photo, :pict
    end
  end

  private

  def run_without_connection
    original_connection = ActiveRecord::Base.remove_connection
    begin
      yield original_connection
    ensure
      ActiveRecord::Base.establish_connection(original_connection)
    end
  end

end