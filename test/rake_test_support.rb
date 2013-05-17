require 'test_helper'
require 'pathname'

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
    @_prev_application = Rake.application
    @_prev_configurations = ActiveRecord::Base.configurations

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
        # RAILS_4x :
        # ActiveRecord::Base.configurations = ActiveRecord::Tasks::DatabaseTasks.database_configuration || {}
        # ActiveRecord::Migrator.migrations_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths
        # 2.3 :
        # ActiveRecord::Base.configurations = Rails::Configuration.new.database_configuration
        ActiveRecord::Base.configurations = configurations
      end
    end

    task(:environment) { @full_env_loaded = true }
    
    if RAILS_4x
      ActiveRecord::Tasks::DatabaseTasks.env = @rails_env
    else
      task(:rails_env) { @rails_env_set = true }
    end
  end
  
  def teardown
    error = nil
    begin
      do_teardown
    rescue => e
      error = e
    end
    Rake.application = @_prev_application
    restore_rails
    ActiveRecord::Base.configurations = @_prev_configurations
    ActiveRecord::Base.establish_connection(db_config)
    @rails_env_set = nil
    @full_env_loaded = nil
    raise error if error
  end

  def do_teardown
  end
  
  def new_application
    Rake::Application.new
  end
  
  protected
  
  def rails_env
    'unittest'
  end
  
  def db_name
    'test_rake_db'
  end
  
  def db_config
    raise "#db_config not implemented !"
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
    configs = configurations
    Rails::Configuration.module_eval do
      define_method(:database_configuration) { configs }
    end
  end

  def setup_rails3
    configs = configurations
    (class << Rails::Application.config; self ; end).instance_eval do
      define_method(:database_configuration) { configs }
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
  
  def silence_warnings
    prev, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = prev
  end
  
end
