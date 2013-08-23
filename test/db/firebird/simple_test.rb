require 'db/firebird/test_helper'

class FirebirdSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include ColumnNameQuotingTests
  include DirtyAttributeTests
  include CustomSelectTestMethods

  # @override
  def test_insert_returns_id
    # not supported (we pre-select id values from sequences) {#test_exec_insert}
  end

  # @override
  def test_column_names_are_escaped
    conn = ActiveRecord::Base.connection
    quoted = conn.quote_column_name "foo-bar"
    assert_equal "#{column_quote_char}FOO-BAR#{column_quote_char}", quoted
  end

  # @override max 18 digits
  def test_big_decimal
    test_value = 9876543210_12345678.0
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_equal test_value, db_type.big_decimal
  end

  # @override 1.42 ~ 1.4199999570846558
  def test_custom_select_float
    model = DbType.create! :sample_float => 1.42
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_float AS custom_sample_float').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_float AS custom_sample_float')
    end
    assert_instance_of Float, model.custom_sample_float
    custom_sample_float = (model.custom_sample_float * 100).round.to_f / 100
    assert_equal 1.42, custom_sample_float
  end

  # @override
  def test_save_timestamp_with_usec
    timestamp = Time.utc(1942, 11, 30, 01, 53, 59, 123_000)
    e = DbType.create! :sample_timestamp => timestamp
    if ar_version('3.0')
      assert_timestamp_equal timestamp, e.reload.sample_timestamp
    else
      assert_datetime_equal timestamp, e.reload.sample_timestamp # only sec
    end
  end

  # @override
  def test_execute_insert
    # assert_nil
    connection.execute("INSERT INTO entries (ID, TITLE) VALUES (4242, 'inserted-title')")
    assert entry = Entry.find(4242)
    assert_equal 'inserted-title', entry.title
  end

  # @override
  def test_exec_insert
    name_column = Thing.columns.detect { |column| column.name.to_s == 'name' }
    created_column = Thing.columns.detect { |column| column.name.to_s == 'created_at' }
    updated_column = Thing.columns.detect { |column| column.name.to_s == 'updated_at' }
    now = Time.zone.now

    created_date = "'2013-07-23 02:44:58.0451'"
    updated_date = "'2013-07-23 02:44:58.0452'"
    connection.exec_insert "INSERT INTO things VALUES ( '01', #{created_date}, #{updated_date} )", nil, []

    binds = [ [ name_column, 'ferko' ], [ created_column, now ], [ updated_column, now ] ]
    connection.exec_insert "INSERT INTO things VALUES ( ?, ?, ? )", 'INSERT Thing(ferko)', binds
    assert Thing.find_by_name 'ferko'

    result = connection.exec_insert "INSERT INTO entries(ID, TITLE) VALUES ( '4200', 'inserted-title' )", nil, []
    # assert_nil result # returns no generated id

    connection.exec_insert "INSERT INTO entries(ID, TITLE) VALUES ( '4201', 'inserted-title' )", nil, [], 'ID'
  end

  # @override
  def test_exec_insert_bind_param_with_q_mark
    sql = "INSERT INTO entries(id, title) VALUES (?, ?)"
    connection.exec_insert sql, 'INSERT(with_q_mark)', [ [ nil, 1000 ], [ nil, "bar?!?" ] ]

    entries = Entry.find_by_sql "SELECT * FROM entries WHERE title = 'bar?!?'"
    assert entries.first
  end

  # @override
  def test_raw_insert_bind_param_with_q_mark
    sql = "INSERT INTO entries(id, title) VALUES (?, ?)"
    name = "INSERT(raw_with_q_mark)"
    pk = nil; id_value = 1001; sequence_name = nil
    connection.insert sql, name, pk, id_value, sequence_name, [ [ nil, id_value ], [ nil, "?!huu!?" ] ]
    assert Entry.exists?([ 'title LIKE ?', "%?!huu!?%" ])
  end if Test::Unit::TestCase.ar_version('3.1') # no binds argument for <= 3.0

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::Firebird
    assert_kind_of Arel::Visitors::Firebird, visitor
  end if ar_version('3.0')

end

class FirebirdHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
