require 'jdbc_common'
require 'rake'

module AbstractDbCreate
  def setup
    @prevapp = Rake.application
    Rake.application = Rake::Application.new
    verbose(true)
    @prevenv = Object.const_get("RAILS_ENV") rescue nil
    @prevroot = Object.const_get("RAILS_ENV") rescue nil
    Object.const_set("RAILS_ENV", "unittest")
    Object.const_set("RAILS_ROOT", ".")
    @prevconfigs = ActiveRecord::Base.configurations
    ActiveRecord::Base.connection.disconnect!
    @db_name = 'test_rake_db_create'
    require 'initializer'
    the_db_name = @db_name
    the_db_config = db_config
    Rails::Configuration.class_eval do
      define_method(:database_configuration) do
        { "unittest" => the_db_config.merge({:database => the_db_name}).stringify_keys! }
      end
    end
    load rails_databases_rake_file
    load File.dirname(__FILE__) + '/../lib/jdbc_adapter/jdbc.rake' if jruby?
    task :environment; task :rails_env           # dummy environment, rails_env tasks
  end

  def teardown
    Rake::Task["db:drop"].invoke
    Rake.application = @prevapp
    Object.const_set("RAILS_ENV", @prevenv) if @prevenv
    Object.const_set("RAILS_ROOT", @prevroot) if @prevroot
    ActiveRecord::Base.configurations = @prevconfigs
    ActiveRecord::Base.establish_connection(db_config)
  end

  def rails_databases_rake_file
    ar_version = $LOADED_FEATURES.grep(%r{active_record/version}).first
    ar_lib_path = $LOAD_PATH.detect {|p| p if File.exist?File.join(p, ar_version)}
    ar_lib_path = ar_lib_path.sub(%r{activerecord/lib}, 'railties/lib') # edge rails
    rails_lib_path = ar_lib_path.sub(/activerecord/, 'rails') # gem rails
    "#{rails_lib_path}/tasks/databases.rake"
  end
end
