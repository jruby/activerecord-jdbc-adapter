require 'rake_test_support'
require 'db/postgres'

class PostgresRakeTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_config
    POSTGRES_CONFIG
  end

  def do_teardown
    drop_rake_test_database(:silence)
  end

  PSQL_EXE = which('psql')

  test 'rake db:create (and db:drop)' do
    Rake::Task["db:create"].invoke
    if PSQL_EXE
      output = psql("-d template1 -c '\\\l'")
      assert_match /#{db_name}/m, output
    end

    Rake::Task["db:drop"].invoke
    if PSQL_EXE
      output = psql("-d template1 -c '\\\l'")
      assert_no_match /#{db_name}/m, output
    end
  end

  test 'rake db:drop (non-existing database)' do
    drop_rake_test_database(:silence)
    Rake::Task["db:drop"].invoke
  end

  test 'rake db:test:purge' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      connection.create_table('users') { |t| t.string :name }
    end

    Rake::Task["db:test:purge"].invoke

    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    assert_false ActiveRecord::Base.connection.table_exists?('users')
    ActiveRecord::Base.connection.disconnect!
  end

  test 'rake db:test:load_structure' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('testers') { |t| t.string :test }
    end

    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke

      drop_rake_test_database(:silence)
      create_rake_test_database

      Rake::Task["db:test:load_structure"].invoke

      with_connection db_config.merge :database => db_name do |connection|
        assert connection.table_exists?('testers')
      end
    ensure
      File.delete(structure_sql) if File.exists?(structure_sql)
      Dir.rmdir 'db'
    end
  end

  test 'rake db:structure:dump (and db:structure:load)' do
    omit('pg_dump not available') unless self.class.which('pg_dump')
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('users') { |t| t.string :name; t.timestamps }
    end

    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke

      assert File.exists?(structure_sql)
      assert_match /CREATE TABLE users/, File.read(structure_sql)

      # db:structure:load
      drop_rake_test_database(:silence)
      create_rake_test_database
      Rake::Task["db:structure:load"].invoke

      with_connection db_config.merge :database => db_name do |connection|
        assert connection.table_exists?('users')
      end
    ensure
      File.delete(structure_sql) if File.exists?(structure_sql)
      Dir.rmdir 'db'
    end
  end

  setup { rm_r 'db' if File.exist?('db') }

  test 'rake db:charset' do
    create_rake_test_database
    expect_rake_output 'UTF8'
    Rake::Task["db:charset"].invoke
  end

  test 'rake db:collation' do
    create_rake_test_database
    expect_rake_output /\w*?\.UTF-8/ # en_US.UTF-8
    Rake::Task["db:collation"].invoke
  end

  test 'rake db:create does not load full environment' do
    begin
      Rake::Task["db:create"].invoke
      assert @rails_env_set
      assert ! ( @full_environment_loaded ||= nil )
    ensure
      # Rake::Task["db:drop"].invoke rescue nil
      drop_rake_test_database(:silence)
    end
  end if ActiveRecord::VERSION::MAJOR < 4

  private

  def psql(args)
    args = args.join(' ') unless args.is_a?(String)
    if db_config[:host] != 'localhost'
      args = "--host=#{db_config[:host]} #{args}"
    end
    if username = ENV['PSQL_USERNAME']
      args = "--username=#{username} #{args}"
    end
    `#{PSQL_EXE} #{args}`
  end

  if ActiveRecord::VERSION::STRING.start_with?('4.2') && defined?(JRUBY_VERSION) && JRUBY_VERSION.start_with?('1.7')
    warn "NOTE: patching structure_dump due on JRuby #{JRUBY_VERSION}"
    # NOTE: a hack around structure_dump failing due system(cmd, *args) on 1.7 (not going to get fixed)
    #   RuntimeError: failed to execute:
    # pg_dump -s -x -O -f db/structure.sql test_rake_db
    require 'active_record/tasks/postgresql_database_tasks.rb'
    ActiveRecord::Tasks::PostgreSQLDatabaseTasks.module_eval do
      def run_cmd(cmd, args, action)
        # fail run_cmd_error(cmd, args, action) unless Kernel.system(cmd, *args)
        cmd_full = "#{cmd} #{args.map { |arg| Shellwords.escape(arg) }.join(' ')}"
        fail run_cmd_error(cmd, args, action) unless Kernel.system(cmd_full)
      end
    end
  end

end