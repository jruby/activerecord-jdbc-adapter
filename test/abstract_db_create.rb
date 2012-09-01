require 'jdbc_common'
require 'rake'

module Rails
  class Configuration
  end
  class Application
    def self.config
      @config ||= Object.new
    end
    def self.paths
      @paths ||= Hash.new { [] }
    end
  end
  def self.application
    Rails::Application
  end
end

module AbstractDbCreate
  def self.included(base)
    base.module_eval { include Rake::DSL } if defined?(Rake::DSL)
  end

  def setup
    @prevapp = Rake.application
    Rake.application = Rake::Application.new
    verbose(true)
    do_setup
  end

  def do_setup(env = 'unittest', db = 'test_rake_db_create')
    @env = env
    @prevconfigs = ActiveRecord::Base.configurations
    ActiveRecord::Base.connection.disconnect!
    @db_name = db
    setup_rails
    set_rails_constant("env", @env)
    set_rails_constant("root", ".")
    load File.dirname(__FILE__) + '/../lib/arjdbc/jdbc/jdbc.rake' if jruby?
    task :environment do
      ActiveRecord::Base.configurations = configurations
      @full_env_loaded = true
    end
    task :rails_env do
      @rails_env_set = true
    end
  end

  def teardown
    Rake::Task["db:drop"].invoke
    Rake.application = @prevapp
    restore_rails
    ActiveRecord::Base.configurations = @prevconfigs
    ActiveRecord::Base.establish_connection(db_config)
    @rails_env_set = nil
    @full_env_loaded = nil
  end

  def setup_rails
    if ActiveRecord::VERSION::MAJOR == 3
      setup_rails3
    else
      setup_rails2
    end
  end

  def configurations
    the_db_name = @db_name
    the_db_config = db_config
    the_db_config = the_db_config.merge({:database => the_db_name}) if the_db_name
    the_db_config.stringify_keys!
    @configs = { @env => the_db_config }
    @configs["test"] = @configs[@env].dup
    @configs
  end

  def setup_rails2
    configs = configurations
    Rails::Configuration.class_eval do
      define_method(:database_configuration) { configs }
    end
    ar_version = $LOADED_FEATURES.grep(%r{active_record/version}).first
    ar_lib_path = $LOAD_PATH.detect {|p| p if File.exist?File.join(p, ar_version)}
    # if the old style finder didn't work, assume we have the absolute path already
    if ar_lib_path.nil? && File.exist?(ar_version)
      ar_lib_path = ar_version.sub(%r{/active_record/version.*}, '')
    end
    ar_lib_path = ar_lib_path.sub(%r{activerecord/lib}, 'railties/lib') # edge rails
    rails_lib_path = ar_lib_path.sub(/activerecord-([\d\.]+)/, 'rails-\1') # gem rails
    load "#{rails_lib_path}/tasks/databases.rake"
  end

  def setup_rails3
    configs = configurations
    (class << Rails::Application.config; self ; end).instance_eval do
      define_method(:database_configuration) { configs }
    end
    require 'pathname'
    ar_version = $LOADED_FEATURES.grep(%r{active_record/version}).first
    ar_lib_path = $LOAD_PATH.detect do |p|
      Pathname.new(p).absolute? && ar_version.start_with?(p) ||
        File.exist?(File.join(p, ar_version))
    end
    load "#{ar_lib_path}/active_record/railties/databases.rake"
  end

  def set_rails_constant(name, value)
    cname ="RAILS_#{name.upcase}"
    @constants ||= {}
    @constants[name] = Object.const_get(cname) rescue nil
    silence_warnings { Object.const_set(cname, value) }
    Rails.instance_eval do
      if instance_methods(false).include?(name)
        alias_method "orig_#{name}", name
        define_method(name) { value }
      end
    end
  end

  def restore_rails
    @constants.each do |key,value|
      silence_warnings { Object.const_set("RAILS_#{key.upcase}", value) }
      Rails.instance_eval do
        if instance_methods(false).include?(name)
          remove_method name
          alias_method name, "orig_#{name}"
        end
      end
    end
  end

  def silence_warnings
    prev, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = prev
  end
end
