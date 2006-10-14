module MigrationSetup
  def setup
    CreateEntries.up
  end

  def teardown
    CreateEntries.down
  end
end

module FixtureSetup
  include MigrationSetup
  def setup
    super
    @title = "First post!"
    @content = "Hello from JRuby on Rails!"
    @new_title = "First post updated title"
    Entry.create :title => @title, :content => @content
  end
end

module SimpleTestMethods
  include FixtureSetup

   def test_entries_created
     assert ActiveRecord::Base.connection.tables.find{|t| t =~ /^entries$/i}, "entries not created"
   end

   def test_entries_empty
     Entry.delete_all
     assert_equal 0, Entry.count
   end

   def test_create_new_entry
     Entry.delete_all

     post = Entry.new
     post.title = @title
     post.content = @content
     post.save

     assert_equal 1, Entry.count
   end

   def test_find_and_update_entry
     post = Entry.find(:first)
     assert_equal @title, post.title
     assert_equal @content, post.content

     post.title = @new_title
     post.save

     post = Entry.find(:first)
     assert_equal @new_title, post.title
   end

  def test_destroy_entry
    prev_count = Entry.count
    post = Entry.find(:first)
    post.destroy

    assert_equal prev_count - 1, Entry.count
  end

end
