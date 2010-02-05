require 'jdbc_common'
require 'rake'

module Rails
  class Configuration
  end
  class Application
    def self.config
      @config ||= Object.new
    end
  end
end

module AbstractDbCreate
  def setup
    @prevapp = Rake.application
    Rake.application = Rake::Application.new
    verbose(true)
    @prevconfigs = ActiveRecord::Base.configurations
    ActiveRecord::Base.connection.disconnect!
    @db_name = 'test_rake_db_create'
    setup_rails
    set_rails_constant("env", "unittest")
    set_rails_constant("root", ".")
    load File.dirname(__FILE__) + '/../lib/jdbc_adapter/jdbc.rake' if jruby?
    task :environment do
      ActiveRecord::Base.configurations = configurations
    end
    task :rails_env
  end

  def teardown
    Rake::Task["db:drop"].invoke
    Rake.application = @prevapp
    restore_rails
    ActiveRecord::Base.configurations = @prevconfigs
    ActiveRecord::Base.establish_connection(db_config)
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
    @configs = { "unittest" => the_db_config.merge({:database => the_db_name}).stringify_keys! }
  end

  def setup_rails2
    configs = configurations
    Rails::Configuration.class_eval do
      define_method(:database_configuration) { configs }
    end
    ar_version = $LOADED_FEATURES.grep(%r{active_record/version}).first
    ar_lib_path = $LOAD_PATH.detect {|p| p if File.exist?File.join(p, ar_version)}
    ar_lib_path = ar_lib_path.sub(%r{activerecord/lib}, 'railties/lib') # edge rails
    rails_lib_path = ar_lib_path.sub(/activerecord/, 'rails') # gem rails
    load "#{rails_lib_path}/tasks/databases.rake"
  end

  def setup_rails3
    configs = configurations
    (class << Rails::Application.config; self ; end).instance_eval do
      define_method(:database_configuration) { configs }
    end
    ar_version = $LOADED_FEATURES.grep(%r{active_record/version}).first
    ar_lib_path = $LOAD_PATH.detect {|p| p if File.exist?File.join(p, ar_version)}
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
