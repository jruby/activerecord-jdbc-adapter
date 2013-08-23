module ExplainSupportTestMethods

  PRINT_EXPLAIN_OUTPUT = get_system_property('explain.support.output')

  def test_supports_explain
    assert ActiveRecord::Base.connection.supports_explain?
  end

  def test_explain_without_binds
    create_explain_data

    pp = ActiveRecord::Base.connection.explain(
      "SELECT * FROM entries JOIN users on entries.user_id = users.id WHERE entries.rating > 0"
    )
    puts "\n"; puts pp if PRINT_EXPLAIN_OUTPUT
    assert_instance_of String, pp
  end

  def test_explain_with_binds
    create_explain_data

    # "SELECT * FROM entries JOIN users on entries.user_id = users.id WHERE entries.rating > ?"
    arel = Arel::SelectManager.new Entry.arel_engine
    arel.project Arel.star
    arel.from arel_table = Entry.arel_table
    arel.join(User.arel_table).on(arel_table[:user_id].eq User.arel_table[:id])
    arel.where arel_table[:rating].gt Arel::Nodes::BindParam.new('?')

    binds = [ [ Entry.columns.find { |col| col.name.to_s == 'rating' }, 0 ] ]
    pp = ActiveRecord::Base.connection.explain(arel, binds)
    puts "\n"; puts pp if PRINT_EXPLAIN_OUTPUT
    assert_instance_of String, pp
  end

  private
  def create_explain_data
    user_1 = User.create :login => 'user_1'
    user_2 = User.create :login => 'user_2'

    Entry.create :title => 'title_1', :content => 'content_1', :rating => 1, :user_id => user_1.id
    Entry.create :title => 'title_2', :content => 'content_2', :rating => 2, :user_id => user_2.id
    Entry.create :title => 'title_3', :content => 'content', :rating => 0, :user_id => user_1.id
    Entry.create :title => 'title_4', :content => 'content', :rating => 0, :user_id => user_1.id
  end

end