require 'test_helper'

class MSSQLUnitTest < Test::Unit::TestCase

  def self.startup; require 'arjdbc/mssql' end

  # NOTE: lot of tests kindly borrowed from __activerecord-sqlserver-adapter__

  test "get table name" do
    insert_sql = "INSERT INTO [funny_jokes] ([name]) VALUES('Knock knock')"
    update_sql = "UPDATE [customers] SET [address_street] = NULL WHERE [id] = 2"
    select_sql = "SELECT * FROM [customers] WHERE ([customers].[id] = 1)"

    connection = new_adapter_stub
    assert_equal 'funny_jokes', connection.send(:get_table_name, insert_sql)
    assert_equal 'customers', connection.send(:get_table_name, update_sql)
    assert_equal 'customers', connection.send(:get_table_name, select_sql)

    assert_equal '[funny_jokes]', connection.send(:get_table_name, insert_sql, true)
    assert_equal '[customers]', connection.send(:get_table_name, update_sql, true)
    assert_equal '[customers]', connection.send(:get_table_name, select_sql, true)

    select_sql = " SELECT * FROM  customers  WHERE ( customers.id = 1 ) "
    assert_equal 'customers', connection.send(:get_table_name, select_sql)
    assert_equal 'customers', connection.send(:get_table_name, select_sql, true)

    assert_nil connection.send(:get_table_name, 'SELECT 1')
    # NOTE: this has been failing even before refactoring - not sure if it's needed :
    #assert_nil connection.send(:get_table_name, 'SELECT * FROM someFunction()')
    #assert_nil connection.send(:get_table_name, 'SELECT * FROM someFunction() WHERE 1 > 2')
  end

  context "Utils" do

    setup do
      @expected_table_name = 'baz'
      @expected_db_name = 'foo'
      @first_second_table_names = ['[baz]','baz','[bar].[baz]','bar.baz']
      @third_table_names = ['[foo].[bar].[baz]','foo.bar.baz']
      @qualifed_table_names = @first_second_table_names + @third_table_names
    end

    test 'return clean table_name from Utils.unqualify_table_name' do
      @qualifed_table_names.each do |qtn|
        assert_equal @expected_table_name,
          ArJdbc::MSSQL::Utils.unqualify_table_name(qtn),
          "This qualifed_table_name #{qtn} did not unqualify correctly."
      end
    end

    test 'return nil from Utils.unqualify_db_name when table_name is less than 2 qualified' do
      @first_second_table_names.each do |qtn|
        assert_equal nil, ArJdbc::MSSQL::Utils.unqualify_db_name(qtn),
          "This qualifed_table_name #{qtn} did not return nil."
      end
    end

    test 'return clean db_name from Utils.unqualify_db_name when table is thrid level qualified' do
      @third_table_names.each do |qtn|
        assert_equal @expected_db_name,
          ArJdbc::MSSQL::Utils.unqualify_db_name(qtn),
          "This qualifed_table_name #{qtn} did not unqualify the db_name correctly."
      end
    end

    context 'remove_identifier_delimiters' do
      test 'double quotes and square brackets are removed from tablename' do
        tn = '["foo"]'
        assert_equal 'foo', ArJdbc::MSSQL::Utils.send(:remove_identifier_delimiters, tn),
                     "The delimters in the value #{tn} were not removed correctly"
      end

      test 'double quotes and square brackets are removed from tablename with owner/schema' do
        tn = '["foo"].["bar"]'
        assert_equal 'foo.bar', ArJdbc::MSSQL::Utils.send(:remove_identifier_delimiters, tn),
                     "The delimters in the value #{tn} were not removed correctly"
      end

      test 'return correct tablename if no delimiters are present' do
        tn = 'foo'
        assert_equal 'foo', ArJdbc::MSSQL::Utils.send(:remove_identifier_delimiters, tn),
                     "The delimters in the value #{tn} were not removed correctly"
      end

      test 'return correct tablename with owner/schema if no delimiters are present' do
        tn = 'foo.bar'
        assert_equal 'foo.bar', ArJdbc::MSSQL::Utils.send(:remove_identifier_delimiters, tn),
                     "The delimters in the value #{tn} were not removed correctly"
      end
    end


  end

  test "quote column name" do
    connection = new_adapter_stub
    assert_equal "[foo]", connection.quote_column_name("foo")
    assert_equal "[bar]", connection.quote_column_name("[bar]")
    assert_equal "[foo]]bar]", connection.quote_column_name("foo]bar")

    assert_equal "[dbo].[foo]", connection.quote_column_name("dbo.foo")
    assert_equal "[dbo].[bar]", connection.quote_column_name("[dbo].[bar]")
    assert_equal "[foo].[bar]", connection.quote_column_name("[foo].bar")
    assert_equal "[foo].[bar]", connection.quote_column_name("foo.[bar]")
  end

  test "replace limit offset!" do
    mod = ArJdbc::MSSQL::LimitHelpers::SqlServerReplaceLimitOffset
    sql = "SELECT w.*, count(o.object_id) num_objects " <<
      "FROM [vikings] w inner join long_ships s on s.id = w.long_ship_id " <<
      "WHERE (w.long_ship_id > 0) " <<
      "GROUP BY w.long_ship_id, w.name " <<
      "ORDER BY count(o.object_id) DESC"
    order = 'ORDER BY count(o.object_id) DESC'
    sql2 = mod.replace_limit_offset!(sql.dup, 1, 2, order)
    expected = 'SELECT t.* FROM ( SELECT ROW_NUMBER() OVER(ORDER BY count(o.object_id) DESC) AS _row_num, w.*, count(o.object_id) num_objects FROM [vikings] w'
    assert sql2.start_with?(expected), sql2

    order = ' ORDER BY count(o.object_id) DESC'
    mod.replace_limit_offset!(sql, 1, 2, order)
    expected = 'SELECT t.* FROM ( SELECT ROW_NUMBER() OVER( ORDER BY count(o.object_id) DESC) AS _row_num, w.*, count(o.object_id) num_objects FROM [vikings] w'
    assert sql.start_with?(expected), sql
  end

  private

  def new_adapter_stub(config = {})
    config = config.merge :adapter => 'mssql', :sqlserver_version => 2008
    connection = stub('connection'); logger = nil
    connection.stub_everything
    adapter = ActiveRecord::ConnectionAdapters::MSSQLAdapter.new connection, logger, config
    yield(adapter) if block_given?
    adapter
  end

end if defined? JRUBY_VERSION

# This tests ArJdbc::MSSQL#add_lock! without actually connecting to the database.
class MSSQLRowLockingUnitTest < Test::Unit::TestCase

  def self.startup; require 'arjdbc/mssql' end

  def test_find_all
    add_lock_test "Appointment.find(:all)",
      %q{SELECT * FROM appointments},
      %q{SELECT * FROM appointments WITH(ROWLOCK,UPDLOCK)}
  end

  def test_find_first
    add_lock_test "Appointment.find(:first)",
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointments.id) AS _row_num, appointments.* FROM appointments) AS t WHERE t._row_num BETWEEN 1 AND 1},
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointments.id) AS _row_num, appointments.* FROM appointments WITH(ROWLOCK,UPDLOCK) ) AS t WHERE t._row_num BETWEEN 1 AND 1}
  end

  def test_find_all_where
    add_lock_test "AppointmentDetail.find(:all, :conditions => {:name => 'foo', :value => 'bar'})",
      %q{SELECT * FROM appointment_details WHERE (appointment_details.[name] = N'foo' AND appointment_details.[value] = N'bar')},
      %q{SELECT * FROM appointment_details WITH(ROWLOCK,UPDLOCK)  WHERE (appointment_details.[name] = N'foo' AND appointment_details.[value] = N'bar')}
  end

  def test_find_first_where
    add_lock_test "AppointmentDetail.find(:first, :conditions => {:name => 'foo', :value => 'bar'})",
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointment_details.id) AS _row_num, appointment_details.* FROM appointment_details WHERE (appointment_details.[name] = N'foo' AND appointment_details.[value] = N'bar')) AS t WHERE t._row_num BETWEEN 1 AND 1},
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointment_details.id) AS _row_num, appointment_details.* FROM appointment_details WITH(ROWLOCK,UPDLOCK)  WHERE (appointment_details.[name] = N'foo' AND appointment_details.[value] = N'bar')) AS t WHERE t._row_num BETWEEN 1 AND 1}
  end

  def test_find_all_where_array
    add_lock_test "AppointmentDetail.find(:all, :conditions => ['name = ?', 'foo'])",
      %q{SELECT * FROM appointment_details WHERE (name = N'foo')},
      %q{SELECT * FROM appointment_details WITH(ROWLOCK,UPDLOCK)  WHERE (name = N'foo')}
  end

  def test_find_first_where_array
    add_lock_test "AppointmentDetail.find(:first, :conditions => ['name = ?', 'foo'])",
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointment_details.id) AS _row_num, appointment_details.* FROM appointment_details WHERE (name = N'foo')) AS t WHERE t._row_num BETWEEN 1 AND 1},
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointment_details.id) AS _row_num, appointment_details.* FROM appointment_details WITH(ROWLOCK,UPDLOCK)  WHERE (name = N'foo')) AS t WHERE t._row_num BETWEEN 1 AND 1}
  end

  def test_find_all_joins
    add_lock_test "AppointmentDetail.find(:all, :joins => :appointment)",
      %q{SELECT appointment_details.* FROM appointment_details INNER JOIN appointments ON appointments.id = appointment_details.appointment_id},
      %q{SELECT appointment_details.* FROM appointment_details  WITH(ROWLOCK,UPDLOCK) INNER JOIN appointments WITH(ROWLOCK,UPDLOCK)  ON appointments.id = appointment_details.appointment_id}
  end

  def test_find_first_joins
    add_lock_test "AppointmentDetail.find(:first, :joins => :appointment)",
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointment_details.id) AS _row_num, appointment_details.* FROM appointment_details INNER JOIN appointments ON appointments.id = appointment_details.appointment_id) AS t WHERE t._row_num BETWEEN 1 AND 1},
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointment_details.id) AS _row_num, appointment_details.* FROM appointment_details  WITH(ROWLOCK,UPDLOCK) INNER JOIN appointments WITH(ROWLOCK,UPDLOCK)  ON appointments.id = appointment_details.appointment_id) AS t WHERE t._row_num BETWEEN 1 AND 1}
  end

  def test_find_all_2joins
    add_lock_test "Appointment.find(:all, :joins => [:appointment_details, :appointment_hl7s])",
      %q{SELECT appointments.* FROM appointments INNER JOIN appointment_details ON appointment_details.appointment_id = appointments.id INNER JOIN appointment_hl7s ON appointment_hl7s.appointment_id = appointments.id},
      %q{SELECT appointments.* FROM appointments  WITH(ROWLOCK,UPDLOCK) INNER JOIN appointment_details WITH(ROWLOCK,UPDLOCK)  ON appointment_details.appointment_id = appointments.id INNER JOIN appointment_hl7s WITH(ROWLOCK,UPDLOCK)  ON appointment_hl7s.appointment_id = appointments.id}
  end

  def test_find_first_2joins
    add_lock_test "Appointment.find(:first, :joins => [:appointment_details, :appointment_hl7s])",
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointments.id) AS _row_num, appointments.* FROM appointments INNER JOIN appointment_details ON appointment_details.appointment_id = appointments.id INNER JOIN appointment_hl7s ON appointment_hl7s.appointment_id = appointments.id) AS t WHERE t._row_num BETWEEN 1 AND 1},
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointments.id) AS _row_num, appointments.* FROM appointments  WITH(ROWLOCK,UPDLOCK) INNER JOIN appointment_details WITH(ROWLOCK,UPDLOCK)  ON appointment_details.appointment_id = appointments.id INNER JOIN appointment_hl7s WITH(ROWLOCK,UPDLOCK)  ON appointment_hl7s.appointment_id = appointments.id) AS t WHERE t._row_num BETWEEN 1 AND 1}
  end

  def test_find_all_2joins_where
    add_lock_test "Appointment.find(:all, :joins => [:appointment_details, :appointment_hl7s], :conditions => {'appointment_details.name' => 'foo'})",
      %q{SELECT appointments.* FROM appointments INNER JOIN appointment_details ON appointment_details.appointment_id = appointments.id INNER JOIN appointment_hl7s ON appointment_hl7s.appointment_id = appointments.id WHERE (appointment_details.[name] = N'foo')},
      %q{SELECT appointments.* FROM appointments  WITH(ROWLOCK,UPDLOCK) INNER JOIN appointment_details WITH(ROWLOCK,UPDLOCK)  ON appointment_details.appointment_id = appointments.id INNER JOIN appointment_hl7s WITH(ROWLOCK,UPDLOCK)  ON appointment_hl7s.appointment_id = appointments.id WHERE (appointment_details.[name] = N'foo')}
  end

  def test_find_first_2joins_where
    add_lock_test "Appointment.find(:first, :joins => [:appointment_details, :appointment_hl7s], :conditions => {'appointment_details.name' => 'foo'})",
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointments.id) AS _row_num, appointments.* FROM appointments INNER JOIN appointment_details ON appointment_details.appointment_id = appointments.id INNER JOIN appointment_hl7s ON appointment_hl7s.appointment_id = appointments.id WHERE (appointment_details.[name] = N'foo')) AS t WHERE t._row_num BETWEEN 1 AND 1},
      %q{SELECT t.* FROM (SELECT ROW_NUMBER() OVER(ORDER BY appointments.id) AS _row_num, appointments.* FROM appointments  WITH(ROWLOCK,UPDLOCK) INNER JOIN appointment_details WITH(ROWLOCK,UPDLOCK)  ON appointment_details.appointment_id = appointments.id INNER JOIN appointment_hl7s WITH(ROWLOCK,UPDLOCK)  ON appointment_hl7s.appointment_id = appointments.id WHERE (appointment_details.[name] = N'foo')) AS t WHERE t._row_num BETWEEN 1 AND 1}
  end

  def test_custom_join_ar097
    add_lock_test "custom join (arjdbc 0.9.7)",
      %q{
        SELECT t.* FROM (
          SELECT
            ROW_NUMBER() OVER(ORDER BY appointments.id) AS row_num,
            appointments.*
          FROM
            appointments INNER JOIN
            appointment_details AS d1 ON appointments.[id] = d1.[appointment_id]
          WHERE (d1.[name] = N'appointment_identifier' AND d1.[value] = N'279955^MQ')
        ) AS t WHERE t.row_num BETWEEN 1 AND 1
      }, %q{
        SELECT t.* FROM (
          SELECT
            ROW_NUMBER() OVER(ORDER BY appointments.id) AS row_num,
            appointments.*
          FROM
            appointments  WITH(ROWLOCK,UPDLOCK) INNER JOIN
            appointment_details AS d1 WITH(ROWLOCK,UPDLOCK)  ON appointments.[id] = d1.[appointment_id]
          WHERE (d1.[name] = N'appointment_identifier' AND d1.[value] = N'279955^MQ')
        ) AS t WHERE t.row_num BETWEEN 1 AND 1
      }
  end

  def test_custom_join_ar111
    add_lock_test "custom join (arjdbc 1.1.1)",
      %q{
        SELECT t.*
        FROM
          (
            SELECT
              ROW_NUMBER() OVER(ORDER BY appointments.id) AS _row_num,
              appointments.*
            FROM
              appointments INNER JOIN
              appointment_details AS d1 ON appointments.[id] = d1.[appointment_id]
            WHERE
              (d1.[name] = N'appointment_identifier' AND d1.[value] = N'389727^MQ')
          ) AS t
        WHERE
          t._row_num BETWEEN 1 AND 1
      }, %q{
        SELECT t.*
        FROM
          (
            SELECT
              ROW_NUMBER() OVER(ORDER BY appointments.id) AS _row_num,
              appointments.*
            FROM
              appointments  WITH(ROWLOCK,UPDLOCK) INNER JOIN
              appointment_details AS d1 WITH(ROWLOCK,UPDLOCK)  ON appointments.[id] = d1.[appointment_id]
            WHERE
              (d1.[name] = N'appointment_identifier' AND d1.[value] = N'389727^MQ')
          ) AS t
        WHERE
          t._row_num BETWEEN 1 AND 1
      }
  end

  class Dummy; end

  private

  def add_lock!(sql, options={})
    result = sql.dup
    mod = ::ArJdbc::MSSQL::LockMethods
    Dummy.send(:include, mod) unless Dummy.include?(mod)
    Dummy.new.add_lock!(result, {:lock=>true}.merge(options))
    result
  end

  def add_lock_test(message, before, after, options={})
    before = before.gsub(/\s*\n\s*/m, " ").strip
    after = after.gsub(/\s*\n\s*/m, " ").strip
    assert_equal after, add_lock!(before, options).strip, message
  end

end if defined? JRUBY_VERSION