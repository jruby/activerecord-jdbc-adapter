class JdbcGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.directory 'config/initializers'
      m.template 'config/initializers/jdbc.rb', File.join('config', 'initializers', 'jdbc.rb')
      m.directory 'lib/tasks'
      m.template 'lib/tasks/jdbc.rake', File.join('lib', 'tasks', 'jdbc.rake')
    end
  end

  protected
  def banner
    "Usage: #{$0} jdbc\nGenerate JDBC bootstrapping files for your Rails application."
  end
end
