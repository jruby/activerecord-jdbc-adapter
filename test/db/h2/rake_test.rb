require 'rake_test_support'
require 'db/h2'

class H2RakeTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_name; 'mem:rake-test'; end

  def do_teardown
    drop_rake_test_database(:silence)
  end

  test 'rake db:create (and db:drop)' do
    @db_name = 'rake-create-test'
    Rake::Task["db:create"].invoke
    db_path = ActiveRecord::Base.connection.database_path
    #assert_true File.exists?(db_path(@db_name)), "db file: #{db_path(@db_name)} is missing"
    assert_true File.exists?(db_path), "db file: #{db_path} is missing"

    Rake::Task["db:drop"].invoke
    assert_false File.exists?(db_path), "db file: #{db_path} not deleted"
  end

  test 'rake db:create (and db:drop) in memory db' do
    Rake::Task["db:create"].invoke
    # assert_true File.exists?("#{db_name}.lck")

    Rake::Task["db:drop"].invoke
    # assert_false File.exists?("#{db_name}.lck")
  end

  test 'rake db:test:purge' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      connection.create_table('loosers') { |t| t.string :name }
    end

    Rake::Task["db:test:purge"].invoke

    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    assert_false ActiveRecord::Base.connection.table_exists?('loosers')
    ActiveRecord::Base.connection.disconnect!
  end

  test 'rake db:structure:dump (and db:structure:load)' do
    db_name = @db_name = 'test-dump-rake'
    create_rake_test_database(db_name) do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('loosers') { |t| t.string :name; t.timestamps }
    end

    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke

      assert File.exists?(structure_sql)
      # CREATE CACHED TABLE PUBLIC.LOOSERS
      assert_match(/CREATE .*? TABLE PUBLIC.LOOSERS/i, File.read(structure_sql))

      # db:structure:load
      drop_rake_test_database(:silence)
      Rake::Task["db:structure:load"].invoke

      ActiveRecord::Base.establish_connection db_config.merge :database => db_name
      assert ActiveRecord::Base.connection.table_exists?('loosers')
      ActiveRecord::Base.connection.disconnect!
    ensure
      File.delete(structure_sql) if File.exists?(structure_sql)
      Dir.rmdir 'db'
    end
  end

#  test 'rake db:charset' do
#    expect_rake_output('UTF-8')
#    Rake::Task["db:charset"].invoke
#  end

  def create_rake_test_database(db_name = self.db_name)
    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    if block_given?
      yield ActiveRecord::Base.connection
    end
    ActiveRecord::Base.connection.disconnect!
  end

  def drop_rake_test_database(silence = nil)
    # ActiveRecord::Base.establish_connection db_config.merge :database => @db_name
    # ActiveRecord::Base.connection.disconnect!

    File.delete("#{@db_name}.lock.db") if File.exist? "#{@db_name}.lock.db"
    File.delete("#{@db_name}.trace.db") if File.exist? "#{@db_name}.trace.db"
    if silence
      File.delete("#{@db_name}.h2.db") if File.exist? "#{@db_name}.h2.db"
      File.delete("#{@db_name}.mv.db") if File.exist? "#{@db_name}.mv.db"
    else
      if File.exist? "#{@db_name}.mv.db"
        File.delete("#{@db_name}.mv.db")
      else
        File.delete("#{@db_name}.h2.db")
      end
    end
  end

  private

  def db_path(db_name, suffix = nil)
    base_path = File.expand_path(db_name)
    return "#{base_path}#{suffix}" if suffix
    return "#{base_path}.h2.db" if File.exist?("#{base_path}.h2.db")
    return "#{base_path}.mv.db" if File.exist?("#{base_path}.mv.db")
    nil
  end

end
