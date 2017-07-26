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
    puts "\n", pp if PRINT_EXPLAIN_OUTPUT
    assert_instance_of String, pp
  end

  def test_explain_with_binds
    create_explain_data

    # "SELECT * FROM entries JOIN users on entries.user_id = users.id WHERE entries.rating > ? LIMIT 1"
    arel = Arel::SelectManager.new Entry.arel_engine
    arel.project Arel.star
    arel.from arel_table = Entry.arel_table
    arel.join(User.arel_table).on(arel_table[:user_id].eq User.arel_table[:id])
    arel.where arel_table[:rating].gt arel_bind_param
    arel.take arel_bind_param

    attr_name = arel_table[:rating].name

    binds = [
        ActiveRecord::Relation::QueryAttribute.new(attr_name, 0, Entry.type_for_attribute(attr_name)),
        ActiveRecord::Attribute.with_cast_value('LIMIT', 1, ActiveModel::Type::Value.new)
    ]

    pp = ActiveRecord::Base.connection.explain(arel, binds)
    puts "\n", pp if PRINT_EXPLAIN_OUTPUT
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
