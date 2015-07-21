require 'test_helper'
require 'db/postgres'

class PostgreSQLTypesTest < Test::Unit::TestCase

  class PostgresqlArray < ActiveRecord::Base; end
  class PostgresqlUUID < ActiveRecord::Base; end
  class PostgresqlRange < ActiveRecord::Base; end
  class PostgresqlTsvector < ActiveRecord::Base; end
  class PostgresqlMoney < ActiveRecord::Base; end
  class PostgresqlNumber < ActiveRecord::Base; end
  class PostgresqlTime < ActiveRecord::Base; end
  class PostgresqlNetworkAddress < ActiveRecord::Base; end
  class PostgresqlBitString < ActiveRecord::Base; end
  class PostgresqlOid < ActiveRecord::Base; end
  class PostgresqlTimestampWithZone < ActiveRecord::Base; end

  # self.use_transactional_fixtures = false

  def self.startup
    super

    execute "CREATE TABLE postgresql_arrays (" <<
              " id SERIAL PRIMARY KEY," <<
              " commission_by_quarter INTEGER[]," <<
              " nicknames TEXT[]" <<
            ");"

    execute "CREATE TABLE postgresql_uuids (" <<
              " id SERIAL PRIMARY KEY," <<
              " guid uuid," <<
              " compact_guid uuid" <<
            ");"

    execute("CREATE TABLE postgresql_ranges (" <<
              " id SERIAL PRIMARY KEY," <<
              " date_range daterange," <<
              " num_range numrange," <<
              " ts_range tsrange," <<
              " tstz_range tstzrange," <<
              " int4_range int4range," <<
              " int8_range int8range" <<
            ");") if supports_ranges?

    execute "CREATE TABLE postgresql_tsvectors ( id SERIAL PRIMARY KEY, text_vector tsvector );"

    execute "CREATE TABLE postgresql_moneys ( id SERIAL PRIMARY KEY, wealth MONEY );"

    execute "CREATE TABLE postgresql_numbers (" <<
              " id SERIAL PRIMARY KEY," <<
              " single REAL," <<
              " double DOUBLE PRECISION" <<
            ");"

    execute "CREATE TABLE postgresql_times (" <<
              " id SERIAL PRIMARY KEY," <<
              " time_interval INTERVAL," <<
              " scaled_time_interval INTERVAL(6)" <<
            ");"

    execute "CREATE TABLE postgresql_network_addresses (" <<
              " id SERIAL PRIMARY KEY," <<
              " cidr_address CIDR default '192.168.1.0/24'," <<
              " inet_address INET default '192.168.1.1'," <<
              " mac_address MACADDR default 'ff:ff:ff:ff:ff:ff'" <<
            ");"

    execute "CREATE TABLE postgresql_bit_strings (" <<
              " id SERIAL PRIMARY KEY," <<
              " bit_string BIT(8)," <<
              " bit_string_varying BIT VARYING(8)" <<
            ");"

    execute "CREATE TABLE postgresql_oids ( id SERIAL PRIMARY KEY, obj_id OID );"

    execute "CREATE TABLE postgresql_timestamp_with_zones ( id SERIAL PRIMARY KEY, time TIMESTAMP WITH TIME ZONE );"
  end

  def self.shutdown
    %w(postgresql_arrays postgresql_uuids postgresql_ranges postgresql_tsvectors
  postgresql_moneys postgresql_numbers  postgresql_times postgresql_network_addresses
  postgresql_bit_strings postgresql_oids postgresql_timestamp_with_zones).each do |table_name|
      execute "DROP TABLE IF EXISTS #{table_name}"
    end
    super
  end

  def self.execute sql
    connection.execute sql
  end

  def self.connection
    ActiveRecord::Base.connection
  end

  def self.supports_ranges?
    if connection.respond_to?(:supports_ranges?)
      !! connection.supports_ranges?
    else
      nil
    end
  end

  def supports_ranges?; self.class.supports_ranges?; end
  private :supports_ranges?

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute("set lc_monetary = 'C'")

    @connection.execute("INSERT INTO postgresql_arrays (id, commission_by_quarter, nicknames) VALUES (1, '{35000,21000,18000,17000}', '{foo,bar,baz}')")
    @first_array = PostgresqlArray.find(1) rescue nil

    @connection.execute <<_SQL if supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '[''2012-01-02'', ''2012-01-04'']',
      '[0.1, 0.2]',
      '[''2010-01-01 14:30'', ''2011-01-01 14:30'']',
      '[''2010-01-01 14:30:00+05'', ''2011-01-01 14:30:00-03'']',
      '[1, 10]',
      '[10, 100]'
    )
_SQL

    @connection.execute <<_SQL if supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '(''2012-01-02'', ''2012-01-04'')',
      '[0.1, 0.2)',
      '[''2010-01-01 14:30'', ''2011-01-01 14:30'')',
      '[''2010-01-01 14:30:00+05'', ''2011-01-01 14:30:00-03'')',
      '(1, 10)',
      '(10, 100)'
    )
_SQL

    @connection.execute <<_SQL if supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '(''2012-01-02'',]',
      '[0.1,]',
      '[''2010-01-01 14:30'',]',
      '[''2010-01-01 14:30:00+05'',]',
      '(1,]',
      '(10,]'
    )
_SQL

    @connection.execute <<_SQL if supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '[,]',
      '[,]',
      '[,]',
      '[,]',
      '[,]',
      '[,]'
    )
_SQL

    @connection.execute <<_SQL if supports_ranges?
    INSERT INTO postgresql_ranges (
      date_range,
      num_range,
      ts_range,
      tstz_range,
      int4_range,
      int8_range
    ) VALUES (
      '(''2012-01-02'', ''2012-01-02'')',
      '(0.1, 0.1)',
      '(''2010-01-01 14:30'', ''2010-01-01 14:30'')',
      '(''2010-01-01 14:30:00+05'', ''2010-01-01 06:30:00-03'')',
      '(1, 1)',
      '(10, 10)'
    )
_SQL

    if supports_ranges?
      @first_range = PostgresqlRange.find(1)
      @second_range = PostgresqlRange.find(2)
      @third_range = PostgresqlRange.find(3)
      @fourth_range = PostgresqlRange.find(4)
      @empty_range = PostgresqlRange.find(5)
    end

    @connection.execute("INSERT INTO postgresql_tsvectors (id, text_vector) VALUES (1, ' ''text'' ''vector'' ')")

    @first_tsvector = PostgresqlTsvector.find(1)

    @connection.execute("INSERT INTO postgresql_moneys (id, wealth) VALUES (1, '567.89'::money)")
    @connection.execute("INSERT INTO postgresql_moneys (id, wealth) VALUES (2, '-567.89'::money)")
    @first_money = PostgresqlMoney.find(1)
    @second_money = PostgresqlMoney.find(2)

    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (1, 123.456, 123456.789)")
    @first_number = PostgresqlNumber.find(1)

    @connection.execute("INSERT INTO postgresql_times (id, time_interval, scaled_time_interval) VALUES (1, '1 year 2 days ago', '3 weeks ago')")
    @first_time = PostgresqlTime.find(1)

    @connection.execute("INSERT INTO postgresql_network_addresses (id, cidr_address, inet_address, mac_address) VALUES(1, '192.168.0/24', '172.16.1.254/32', '01:23:45:67:89:0a')")
    @first_network_address = PostgresqlNetworkAddress.find(1)

    @connection.execute("INSERT INTO postgresql_bit_strings (id, bit_string, bit_string_varying) VALUES (1, B'00010101', X'15')")
    @first_bit_string = PostgresqlBitString.find(1)

    @connection.execute("INSERT INTO postgresql_oids (id, obj_id) VALUES (1, 1234)")
    @first_oid = PostgresqlOid.find(1)

    @connection.execute("INSERT INTO postgresql_timestamp_with_zones (id, time) VALUES (1, '2010-01-01 10:00:00-1')")

    @connection.execute("INSERT INTO postgresql_uuids (id, guid, compact_guid) VALUES(1, 'd96c3da0-96c1-012f-1316-64ce8f32c6d8', 'f06c715096c1012f131764ce8f32c6d8')")
    @first_uuid = PostgresqlUUID.find(1)
  end

  def teardown
    [PostgresqlArray, PostgresqlTsvector, PostgresqlMoney, PostgresqlNumber, PostgresqlTime, PostgresqlNetworkAddress,
     PostgresqlBitString, PostgresqlOid, PostgresqlTimestampWithZone, PostgresqlUUID].each(&:delete_all)
  end

  def test_data_type_of_array_types
    omit_unless @first_array
    if ar_version('4.0')
      assert_equal :integer, @first_array.column_for_attribute(:commission_by_quarter).type
      assert_equal :text, @first_array.column_for_attribute(:nicknames).type
    else
      assert_equal :string, @first_array.column_for_attribute(:commission_by_quarter).type
      # assert_equal :string, @first_array.column_for_attribute(:nicknames).type
    end
  end

  def test_data_type_of_range_types
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    assert_equal :daterange, @first_range.column_for_attribute(:date_range).type
    assert_equal :numrange, @first_range.column_for_attribute(:num_range).type
    assert_equal :tsrange, @first_range.column_for_attribute(:ts_range).type
    assert_equal :tstzrange, @first_range.column_for_attribute(:tstz_range).type
    assert_equal :int4range, @first_range.column_for_attribute(:int4_range).type
    assert_equal :int8range, @first_range.column_for_attribute(:int8_range).type
  end if ar_version('4.0')

  def test_data_type_of_tsvector_types
    assert_equal :tsvector, @first_tsvector.column_for_attribute(:text_vector).type
  end if ar_version('4.0')

  def test_data_type_of_money_types
    if ar_version('4.2')
      assert_equal :money, @first_money.column_for_attribute(:wealth).type
    else
      assert_equal :decimal, @first_money.column_for_attribute(:wealth).type
    end
  end

  def test_data_type_of_number_types
    assert_equal :float, @first_number.column_for_attribute(:single).type
    assert_equal :float, @first_number.column_for_attribute(:double).type
  end

  def test_data_type_of_time_types
    assert_equal :string, @first_time.column_for_attribute(:time_interval).type
    assert_equal :string, @first_time.column_for_attribute(:scaled_time_interval).type if ar_version('4.0')
  end

  def test_data_type_of_network_address_types
    assert_equal :cidr, @first_network_address.column_for_attribute(:cidr_address).type
    assert_equal :inet, @first_network_address.column_for_attribute(:inet_address).type
    assert_equal :macaddr, @first_network_address.column_for_attribute(:mac_address).type
  end if ar_version('4.0')

  def test_data_type_of_bit_string_types
    bit_column = @first_bit_string.column_for_attribute(:bit_string)
    bit_varying_column = @first_bit_string.column_for_attribute(:bit_string_varying)
    if ar_version('4.2')
      assert_equal :bit, bit_column.type
      assert_equal :bit_varying, bit_varying_column.type
    else
      assert_equal :string, bit_column.type
      assert_equal :string, bit_varying_column.type
    end
  end

  def test_data_type_of_oid_types
    assert_equal :integer, @first_oid.column_for_attribute(:obj_id).type
  end

  def test_data_type_of_uuid_types
    assert_equal :uuid, @first_uuid.column_for_attribute(:guid).type
  end if ar_version('4.0')

  def test_array_values
    omit_unless @first_array
    assert_equal [35000,21000,18000,17000], @first_array.commission_by_quarter
    assert_equal ['foo','bar','baz'], @first_array.nicknames
  end if ar_version('4.0')

  def test_tsvector_values
    assert_equal "'text' 'vector'", @first_tsvector.text_vector
  end

  def test_int4range_values
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    assert_equal 1...11, @first_range.int4_range
    assert_equal 2...10, @second_range.int4_range
    assert_equal nil, @empty_range.int4_range
    assert_equal 2...Float::INFINITY, @third_range.int4_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.int4_range)
  end if ar_version('4.0')

  def test_int8range_values
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    assert_equal 10...101, @first_range.int8_range
    assert_equal 11...100, @second_range.int8_range
    assert_equal nil, @empty_range.int8_range
    assert_equal 11...Float::INFINITY, @third_range.int8_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.int8_range)
  end if ar_version('4.0')

  def test_daterange_values
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    assert_equal Date.new(2012, 1, 2)...Date.new(2012, 1, 5), @first_range.date_range
    assert_equal Date.new(2012, 1, 3)...Date.new(2012, 1, 4), @second_range.date_range
    assert_equal nil, @empty_range.date_range

    assert_equal Date.new(2012, 1, 3)...Float::INFINITY, @third_range.date_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.date_range)
  end if ar_version('4.0')

  def test_numrange_values
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    assert_equal BigDecimal.new('0.1')..BigDecimal.new('0.2'), @first_range.num_range
    assert_equal BigDecimal.new('0.1')...BigDecimal.new('0.2'), @second_range.num_range
    assert_equal BigDecimal.new('0.1')...BigDecimal.new('Infinity'), @third_range.num_range
    assert_equal BigDecimal.new('-Infinity')...BigDecimal.new('Infinity'), @fourth_range.num_range
    assert_equal nil, @empty_range.num_range
  end if ar_version('4.0')

  def test_tsrange_values
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    tz = ::ActiveRecord::Base.default_timezone
    assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)..Time.send(tz, 2011, 1, 1, 14, 30, 0), @first_range.ts_range
    assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 1, 1, 14, 30, 0), @second_range.ts_range
    assert_equal nil, @empty_range.ts_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.ts_range)
    #omit "JRuby 1.7.4 does not handle Time...Infinity ranges" if defined?(JRUBY_VERSION) && JRUBY_VERSION =~ /1\.7\.4/
    #assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)...Float::INFINITY, @third_range.ts_range
  end if ar_version('4.0')

  def test_tstzrange_values
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    assert_equal Time.parse('2010-01-01 09:30:00 UTC')..Time.parse('2011-01-01 17:30:00 UTC'), @first_range.tstz_range
    assert_equal Time.parse('2010-01-01 09:30:00 UTC')...Time.parse('2011-01-01 17:30:00 UTC'), @second_range.tstz_range
    assert_equal nil, @empty_range.tstz_range
    assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.tstz_range)
    #omit "JRuby 1.7.4 does not handle Time...Infinity ranges" if defined?(JRUBY_VERSION) && JRUBY_VERSION =~ /1\.7\.4/
    #assert_equal Time.parse('2010-01-01 09:30:00 UTC')...Float::INFINITY, @third_range.tstz_range
  end if ar_version('4.0')

  def test_money_values
    assert_equal 567.89, @first_money.wealth
    assert_equal -567.89, @second_money.wealth
  end

  def test_create_tstzrange
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    tstzrange = Time.parse('2010-01-01 14:30:00 +0100')...Time.parse('2011-02-02 14:30:00 CDT')
    range = PostgresqlRange.new(:tstz_range => tstzrange)
    assert range.save
    assert range.reload
    assert_equal range.tstz_range, tstzrange
    assert_equal range.tstz_range, Time.parse('2010-01-01 13:30:00 UTC')...Time.parse('2011-02-02 19:30:00 UTC')
  end if ar_version('4.0')

  def test_update_tstzrange
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    new_tstzrange = Time.parse('2010-01-01 14:30:00 CDT')...Time.parse('2011-02-02 14:30:00 CET')
    assert @first_range.tstz_range = new_tstzrange
    assert @first_range.save
    assert @first_range.reload
    assert_equal new_tstzrange, @first_range.tstz_range
    assert @first_range.tstz_range = Time.parse('2010-01-01 14:30:00 +0100')...Time.parse('2010-01-01 13:30:00 +0000')
    assert @first_range.save
    assert @first_range.reload
    assert_equal @first_range.tstz_range, nil
  end if ar_version('4.0')

  def test_create_tsrange
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    tz = ::ActiveRecord::Base.default_timezone
    tsrange = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 2, 2, 14, 30, 0)
    range = PostgresqlRange.new(:ts_range => tsrange)
    assert range.save
    assert range.reload
    assert_equal range.ts_range, tsrange
  end if ar_version('4.0')

  def test_update_tsrange
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    tz = ::ActiveRecord::Base.default_timezone
    new_tsrange = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 2, 2, 14, 30, 0)
    assert @first_range.ts_range = new_tsrange
    assert @first_range.save
    assert @first_range.reload
    assert_equal new_tsrange, @first_range.ts_range
    assert @first_range.ts_range = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2010, 1, 1, 14, 30, 0)
    assert @first_range.save
    assert @first_range.reload
    assert_nil @first_range.ts_range
  end if ar_version('4.0')

  def test_create_numrange
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    numrange = BigDecimal.new('0.5')...BigDecimal.new('1')
    range = PostgresqlRange.new(:num_range => numrange)
    assert range.save
    assert range.reload
    assert_equal range.num_range, numrange
  end if ar_version('4.0')

  def test_update_numrange
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    new_numrange = BigDecimal.new('0.5')...BigDecimal.new('1')
    assert @first_range.num_range = new_numrange
    assert @first_range.save
    assert @first_range.reload
    assert_equal new_numrange, @first_range.num_range
    assert @first_range.num_range = BigDecimal.new('0.5')...BigDecimal.new('0.5')
    assert @first_range.save
    assert @first_range.reload
    assert_nil @first_range.num_range
  end if ar_version('4.0')

  def test_create_daterange
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    daterange = Range.new(Date.new(2012, 1, 1), Date.new(2013, 1, 1), true)
    range = PostgresqlRange.new(:date_range => daterange)
    assert range.save
    assert range.reload
    assert_equal daterange, range.date_range
  end if ar_version('4.0')

  def test_update_daterange
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    new_daterange = Date.new(2012, 2, 3)...Date.new(2012, 2, 10)
    assert @first_range.date_range = new_daterange
    assert @first_range.save
    assert @first_range.reload
    assert_equal new_daterange, @first_range.date_range
    assert @first_range.date_range = Date.new(2012, 2, 3)...Date.new(2012, 2, 3)
    assert @first_range.save
    assert @first_range.reload
    assert_nil @first_range.date_range
  end if ar_version('4.0')

  def test_create_int4range
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    int4range = Range.new(3, 50, true)
    range = PostgresqlRange.new(:int4_range => int4range)
    assert range.save
    assert range.reload
    assert_equal range.int4_range, int4range
  end if ar_version('4.0')

  def test_update_int4range
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    new_int4range = 6...10
    assert @first_range.int4_range = new_int4range
    assert @first_range.save
    assert @first_range.reload
    assert_equal new_int4range, @first_range.int4_range
    assert @first_range.int4_range = 3...3
    assert @first_range.save
    assert @first_range.reload
    assert_nil @first_range.int4_range
  end if ar_version('4.0')

  def test_create_int8range
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    int8range = Range.new(30, 50, true)
    range = PostgresqlRange.new(:int8_range => int8range)
    assert range.save
    assert range.reload
    assert_equal int8range, range.int8_range
  end if ar_version('4.0')

  def test_update_int8range
    skip "PostgreSQL 9.2 required for range datatypes" unless supports_ranges?
    new_int8range = 60000...10000000
    assert @first_range.int8_range = new_int8range
    assert @first_range.save
    assert @first_range.reload
    assert_equal new_int8range, @first_range.int8_range
    assert @first_range.int8_range = 39999...39999
    assert @first_range.save
    assert @first_range.reload
    assert_nil @first_range.int8_range
  end if ar_version('4.0')

  def test_update_tsvector
    new_text_vector = "'new' 'text' 'vector'"
    assert @first_tsvector.text_vector = new_text_vector
    assert @first_tsvector.save
    assert @first_tsvector.reload
    assert @first_tsvector.text_vector = new_text_vector
    assert @first_tsvector.save
    assert @first_tsvector.reload
    assert_equal new_text_vector, @first_tsvector.text_vector
  end if ar_version('4.0')

  def test_number_values
    # assert_equal 123.456, @first_number.single
    # NOTE: JDBC API gets us: ~ 123.456
    assert_equal 123.456, ( @first_number.single * 1000 ).to_i / 1000.0
    assert_equal 123456.789, @first_number.double
  end

  def test_time_values
    # omit_unless ar_version('4.0')
    assert_equal '-1 years -2 days', @first_time.time_interval
    assert_equal '-21 days', @first_time.scaled_time_interval if ar_version('4.0')
  end

  def test_network_address_values_ipaddr
    cidr_address = IPAddr.new '192.168.0.0/24'
    inet_address = IPAddr.new '172.16.1.254'

    assert_equal cidr_address, @first_network_address.cidr_address
    assert_equal inet_address, @first_network_address.inet_address
    assert_equal '01:23:45:67:89:0a', @first_network_address.mac_address
  end if ar_version('4.0')

  def test_uuid_values
    assert_equal 'd96c3da0-96c1-012f-1316-64ce8f32c6d8', @first_uuid.guid
    assert_equal 'f06c7150-96c1-012f-1317-64ce8f32c6d8', @first_uuid.compact_guid
  end

  def test_bit_string_values
    assert_equal '00010101', @first_bit_string.bit_string
    assert_equal '00010101', @first_bit_string.bit_string_varying
  end

  def test_oid_values
    assert_equal 1234, @first_oid.obj_id
  end

  def test_update_integer_array
    omit_unless @first_array
    new_value = [32800,95000,29350,17000]
    @first_array.commission_by_quarter = new_value
    @first_array.save!
    assert_equal new_value, @first_array.reload.commission_by_quarter
    @first_array.commission_by_quarter = new_value
    assert @first_array.save
    assert_equal new_value, @first_array.reload.commission_by_quarter
  end if ar_version('4.0')

  def test_update_text_array
    omit_unless @first_array
    new_value = ['robby','robert','rob','robbie']
    @first_array.nicknames = new_value
    @first_array.save!
    @first_array.reload
    assert_equal new_value, @first_array.nicknames
    @first_array.nicknames = new_value
    @first_array.save!
    @first_array.reload
    assert_equal new_value, @first_array.nicknames
  end if ar_version('4.0')

  def test_update_money
    new_value = BigDecimal.new('123.45')
    @first_money.wealth = new_value
    @first_money.save!
    @first_money.reload
    assert_equal new_value, @first_money.wealth
  end

  def test_money_type_cast
    column = PostgresqlMoney.columns.find { |c| c.name == 'wealth' }
    if ar_version('4.2')
      assert_equal(12345678.12, column.type_cast_from_database("$12,345,678.12"))
      assert_equal(12345678.12, column.type_cast_from_database("$12.345.678,12"))
      assert_equal(-1.15, column.type_cast_from_database("-$1.15"))
      assert_equal(-2.25, column.type_cast_from_database("($2.25)"))
    else
      assert_equal(12345678.12, column.type_cast("$12,345,678.12"))
      assert_equal(12345678.12, column.type_cast("$12.345.678,12"))
      assert_equal(-1.15, column.type_cast("-$1.15"))
      assert_equal(-2.25, column.type_cast("($2.25)"))
    end
  end

  def test_update_number
    new_single = 789.012
    new_double = 789012.345
    @first_number.single = new_single
    @first_number.double = new_double
    @first_number.save!
    @first_number.reload
    # assert_equal new_single, @first_number.single
    # NOTE: JDBC API gets us: ~ 789.012 (due double precision)
    assert_equal new_single, ( @first_number.single * 1000 ).to_i / 1000.0
    assert_equal new_double, @first_number.double
  end

  def test_update_time
    @first_time.time_interval = '2 years 3 minutes'
    @first_time.save!
    @first_time.reload
    assert_equal '2 years 00:03:00', @first_time.time_interval
  end

  def test_update_network_address
    new_inet_address = '10.1.2.3/32'
    new_cidr_address = '10.0.0.0/8'
    new_mac_address = 'bc:de:f0:12:34:56'
    @first_network_address.cidr_address = new_cidr_address
    @first_network_address.inet_address = new_inet_address
    @first_network_address.mac_address = new_mac_address
    @first_network_address.save!
    @first_network_address.reload
    assert_equal '10.0.0.0', @first_network_address.cidr_address.to_s
    assert_equal '10.1.2.3', @first_network_address.inet_address.to_s
    assert_equal new_mac_address, @first_network_address.mac_address
  end if ar_version('4.0')

  def test_update_bit_string

    pend 'not supported by driver' if prepared_statements?
    # org.postgresql.util.PSQLException: ERROR: column "bit_string" is of type bit but expression is of type character varying
    # NOTE: possible work-aroud would be if AREL generated a query like :
    # "INSERT INTO bit_strings VALUES (?::bit)"

    @first_bit_string.bit_string = '11111111'
    assert @first_bit_string.save
    assert_equal '11111111', @first_bit_string.reload.bit_string

    if ar_version('4.0')
      @first_bit_string.bit_string_varying = '0xFF'
      assert @first_bit_string.save
      assert_equal '11111111', @first_bit_string.reload.bit_string_varying
    end
  end

  def test_invalid_hex_bit_string
    @first_bit_string.bit_string = 'FF'
    disable_logger do
      assert_raise(ActiveRecord::StatementInvalid) do
        @first_bit_string.save
      end
    end
  end if ar_version('4.0') && !ar_version('4.2')

  def test_hex_to_bit_string
    pend 'not supported by driver' if prepared_statements?
    @first_bit_string.bit_string = 'FF'
    disable_logger do
      @first_bit_string.save
      assert_equal '11111111', @first_bit_string.reload.bit_string
    end
  end if ar_version('4.2')

  def test_update_oid
    new_value = 567890
    @first_oid.obj_id = new_value
    @first_oid.save!
    assert_equal new_value, @first_oid.reload.obj_id
  end

  def test_timestamp_with_zone_values_with_rails_time_zone_support
    old_tz = ActiveRecord::Base.time_zone_aware_attributes
    old_default_tz = ActiveRecord::Base.default_timezone

    ActiveRecord::Base.time_zone_aware_attributes = true
    ActiveRecord::Base.default_timezone = :utc

    @connection.reconnect!

    @first_timestamp_with_zone = PostgresqlTimestampWithZone.find(1)
    assert_equal Time.utc(2010,1,1, 11,0,0), @first_timestamp_with_zone.time
    assert_instance_of Time, @first_timestamp_with_zone.time
  ensure
    ActiveRecord::Base.default_timezone = old_default_tz
    ActiveRecord::Base.time_zone_aware_attributes = old_tz
    @connection.reconnect!
  end if ar_version('3.0')

  def test_timestamp_with_zone_values_without_rails_time_zone_support
    old_tz = ActiveRecord::Base.time_zone_aware_attributes
    old_default_tz = ActiveRecord::Base.default_timezone

    ActiveRecord::Base.time_zone_aware_attributes = false
    ActiveRecord::Base.default_timezone = :local

    @connection.reconnect!

    @first_timestamp_with_zone = PostgresqlTimestampWithZone.find(1)
    assert_equal Time.utc(2010,1,1, 11,0,0), @first_timestamp_with_zone.time
    assert_instance_of Time, @first_timestamp_with_zone.time
  ensure
    ActiveRecord::Base.default_timezone = old_default_tz
    ActiveRecord::Base.time_zone_aware_attributes = old_tz
    @connection.reconnect!
  end if ar_version('3.0')

  def test_marshal_types
    Marshal.dump @first_array
    Marshal.dump @first_bit_string
    Marshal.dump @first_tsvector
    Marshal.dump @first_oid
    Marshal.dump @first_uuid
    Marshal.dump @first_range ||= nil
    Marshal.dump PostgresqlTimestampWithZone.new
  end

end
