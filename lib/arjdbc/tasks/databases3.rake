# NOTE: fake these for create_database(config)
module Mysql
  Error = ActiveRecord::JDBCError unless const_defined?(:Error)
end
module Mysql2
  Error = ActiveRecord::JDBCError unless const_defined?(:Error)
end
  
namespace :db do

#  namespace :create do
#    task :all => :rails_env
#  end
#
#  namespace :drop do
#    task :all => :environment
#  end
  
  class << self
    alias_method :_rails_create_database, :create_database
    alias_method :_rails_drop_database,   :drop_database
  end
  
  def create_database(config)
    if config['adapter'] =~ /mysql|postgresql|sqlite/i
      return _rails_create_database adapt_jdbc_config(config)
    end
    begin
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection
    rescue # database does not exists :
      url = config['url']
      url = $1 if url && url =~ /^(.*(?<!\/)\/)(?=\w)/
      ActiveRecord::Base.establish_connection(config.merge('database' => nil, 'url' => url))
      ActiveRecord::Base.connection.create_database(config['database'], config)
      ActiveRecord::Base.establish_connection(config)
    end
  end

  def drop_database(config)
    _rails_drop_database adapt_jdbc_config(config)
  end
  
  private
  def adapt_jdbc_config(config)
    config.merge 'adapter' => config['adapter'].sub(/^jdbc/, '')
  end
  
end