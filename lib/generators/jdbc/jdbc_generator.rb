class JdbcGenerator < Rails::Generators::Base
  def self.source_root
    @source_root ||= File.expand_path('../../../../rails_generators/templates', __FILE__)
  end

  def create_jdbc_files
    directory '.', '.'
  end

  def self.desc(description=nil)
    return super if description
    "Description:\n" <<
    "  Creates stubs that ensure AR-JDBC is bootstrapped in your Rails application.\n" <<
    "  NOTE: you should not need this if you're on Rails >= 3.0 (using Bundler) ..."
  end

end
