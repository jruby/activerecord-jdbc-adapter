require 'test_helper'
require 'pathname'
require 'stringio'

module RakeTestSupport

  def self.included(base)
    require 'rake'
    base.module_eval { include Rake::DSL } # if defined?(Rake::DSL)
    base.extend ClassMethods
  end

  module ClassMethods

    def startup
      super
      load 'rails_stub.rb'
    end

    def shutdown
      Object.send(:remove_const, :Rails)
      super
    end

  end

  def setup
    __file__ = File.expand_path('../../lib/arjdbc/tasks/databases.rake', __FILE__)
    main.stubs(:warn).with("double loading #{__file__} please delete lib/tasks/jdbc.rake if present!")

    @_prev_application = Rake.application
    @_prev_configurations = ActiveRecord::Base.configurations
    @_prev_connection_config = current_connection_config
    db_config # if not re-defined initialize from current connection's config

    @db_name = db_name unless @db_name ||= nil
    @rails_env = rails_env unless @rails_env ||= nil

    setup_rails
    set_rails_env(@rails_env)
    set_rails_root(".")

    Rake.application = new_application
    ActiveRecord::Base.connection.disconnect!

    verbose(true)

    load_tasks

    do_setup
  end

  def do_setup
  end

  RAILS_4x = ActiveRecord::VERSION::MAJOR >= 4

  def load_tasks
    if ActiveRecord::VERSION::MAJOR >= 3
      load "active_record/railties/databases.rake"
    else # we still support AR-2.3
      load "tasks/databases.rake" # from rails/railties
    end
    load 'arjdbc/tasks.rb' if defined?(JRUBY_VERSION)

    namespace :db do
      task :load_config do
        # 4.0 :
        # ActiveRecord::Base.configurations = ActiveRecord::Tasks::DatabaseTasks.database_configuration || {}
        # ActiveRecord::Migrator.migrations_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths
        # 3.2 :
        # ActiveRecord::Base.configurations = Rails.application.config.database_configuration
        # ActiveRecord::Migrator.migrations_paths = Rails.application.paths['db/migrate'].to_a
        # 2.3 :
        # ActiveRecord::Base.configurations = Rails::Configuration.new.database_configuration
        ActiveRecord::Base.configurations = configurations
      end
    end

    task :environment do
      ActiveRecord::Base.configurations = configurations
      ActiveRecord::Base.establish_connection @rails_env.to_sym
      @full_env_loaded = true
    end

    if RAILS_4x
      ActiveRecord::Tasks::DatabaseTasks.env = @rails_env
      ActiveRecord::Tasks::DatabaseTasks.db_dir = 'db'
      if ActiveRecord::Tasks::DatabaseTasks.respond_to? :root=
        ActiveRecord::Tasks::DatabaseTasks.root = Rails.root # since 4.0.1
      end
    else
      task(:rails_env) { @rails_env_set = true }
    end
  end

  def teardown
    stdout = restore_stdout

    error = nil
    begin
      do_teardown
    rescue => e
      error = e
    end
    Rake.application = @_prev_application
    restore_rails
    ActiveRecord::Base.configurations = @_prev_configurations
    ActiveRecord::Base.establish_connection @_prev_connection_config
    @rails_env_set = nil
    @full_env_loaded = nil
    raise error if error

    assert_stdout(stdout)
  end

  def do_teardown
  end

  def new_application
    Rake::Application.new
  end

  # (Test) Helpers :

  def create_schema_migrations_table(connection = ActiveRecord::Base.connection)
    schema_migration = ActiveRecord::Migrator.schema_migrations_table_name
    return if connection.table_exists?(schema_migration)
    connection.create_table(schema_migration, :id => false) do |t|
      t.column :version, :string, :null => false
    end
  end

  def create_rake_test_database
    ActiveRecord::Base.establish_connection db_config
    connection = ActiveRecord::Base.connection
    connection.create_database(db_name, db_config) if connection.respond_to?(:create_database)
    if block_given?
      if db_name
        config = db_config.merge :database => db_name
        ActiveRecord::Base.establish_connection config
      end
      yield ActiveRecord::Base.connection
    end
    ActiveRecord::Base.connection.disconnect!
  end

  def drop_rake_test_database(silence = false)
    ActiveRecord::Base.establish_connection db_config
    begin
      ActiveRecord::Base.connection.drop_database(db_name)
    rescue => e
      raise e unless silence
    end
    ActiveRecord::Base.connection.disconnect!
  end

  def structure_sql_filename
    ar_version('3.2') ? 'structure.sql' : "#{@rails_env}_structure.sql"
  end

  def with_connection(config = db_config)
    ActiveRecord::Base.establish_connection config
    yield ActiveRecord::Base.connection
    ActiveRecord::Base.connection.disconnect!
  end

  def expect_rake_output(matcher)
    @_stdout, @_stdout_matcher = $stdout, matcher
    $stdout = StringIO.new
  end

  def assert_stdout(stdout)
    return if stdout != false

    if @_stdout_matcher.is_a?(String)
      unless @_stdout_matcher.index("\n")
        stdout = stdout.rstrip
      end
      assert_equal @_stdout_matcher, stdout
    else
      assert_match @_stdout_matcher, stdout
    end
  end
  private :assert_stdout

  def restore_stdout
    if @_stdout ||= false
      _stdout = $stdout
      $stdout = @_stdout

      _stdout.string
    end
  end
  private :restore_stdout

  def rails_env; 'unittest' end

  def db_name; 'test_rake_db' end

  @@db_config = nil

  def db_config
    @@db_config ||= current_connection_config.reject { |key, val| val && key.to_s == 'url' }
  end

  def configurations
    @configurations ||= begin
      db_config = self.db_config.dup
      db_config.merge!(:database => @db_name) if @db_name ||= nil
      db_config.stringify_keys!
      raise "Rails.env not set" unless @rails_env ||= nil
      configurations = { @rails_env => db_config }
      configurations['test'] = db_config.dup
      configurations
    end
  end

  private

  RAILS_2x = ActiveRecord::VERSION::MAJOR < 3

  def setup_rails
    RAILS_2x ? setup_rails2 : setup_rails3
  end

  def setup_rails2
    test = self
    Rails::Configuration.module_eval do
      define_method(:database_configuration) { test.configurations }
    end
  end

  def setup_rails3
    test = self
    (class << Rails::Application.config; self ; end).instance_eval do
      define_method(:database_configuration) { test.configurations }
    end
  end

  def set_rails_env(env); set_rails_constant("env", env); end

  def set_rails_root(root = '.'); set_rails_constant("root", root); end

  NO_VALUE = Java::JavaLang::Void rescue NilClass

  def set_rails_constant(name, value)
    name = name.to_s

    @rails_constants ||= {}
    begin
      @rails_constants[name] = Object.const_get(rails_constant_name(name))
    rescue NameError
      @rails_constants[name] = NO_VALUE
    end
    silence_warnings { Object.const_set(rails_constant_name(name), value) } if RAILS_2x

    case name
    when 'env'
      unless value.is_a?(ActiveSupport::StringInquirer)
        value = ActiveSupport::StringInquirer.new(value)
      end
    when 'root'
      unless value.is_a?(Pathname)
        value = Pathname.new(value).realpath
      end
    end

    Rails.instance_eval do
      if methods(false).map(&:to_s).include?(name)
        singleton_class = (class << self; self; end)
        singleton_class.send(:alias_method, "orig_#{name}", name)
        singleton_class.send(:define_method, name) { value }
      end
    end
  end

  def restore_rails
    ( @rails_constants ||= {} ).each do |name, value|

      if value == NO_VALUE
        Object.send(:remove_const, rails_constant_name(name)) if RAILS_2x
      else
        silence_warnings { Object.const_set(rails_constant_name(name), value) }
      end

      Rails.instance_eval do
        if methods(false).map(&:to_s).include?(name)
          singleton_class = (class << self; self; end)
          singleton_class.send :remove_method, name
          singleton_class.send :alias_method, name, "orig_#{name}"
        end
      end

    end
  end

  def rails_constant_name(name); "RAILS_#{name.upcase}"; end

end
