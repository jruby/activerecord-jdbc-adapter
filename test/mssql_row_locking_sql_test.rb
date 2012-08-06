require 'arjdbc/mssql/adapter'
require 'test/unit'

# This tests ArJdbc::MsSQL#add_lock! without actually connecting to the database.
class MssqlRowLockingSqlTest < Test::Unit::TestCase

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


  private

    class Dummy
      include ::ArJdbc::MsSQL::LockHelpers::SqlServerAddLock
    end

    def add_lock!(sql, options={})
      result = sql.dup
      Dummy.new.add_lock!(result, {:lock=>true}.merge(options))
      result
    end

    def add_lock_test(message, before, after, options={})
      before = before.gsub(/\s*\n\s*/m, " ").strip
      after = after.gsub(/\s*\n\s*/m, " ").strip
      assert_equal after, add_lock!(before, options).strip, message
    end
end
