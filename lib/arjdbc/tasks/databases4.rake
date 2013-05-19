
ActiveRecord::Tasks::DatabaseTasks.class_eval do

  unless method_defined?(:_rails_each_current_configuration)
    alias_method :_rails_each_current_configuration, :each_current_configuration
  end

  def each_current_configuration(environment, &block)
    _rails_each_current_configuration(environment) do |config|
      block.call adapt_jdbc_config(config)
    end
  end

  unless method_defined?(:_rails_each_local_configuration)
    alias_method :_rails_each_local_configuration, :each_local_configuration
  end

  def each_local_configuration(&block)
    _rails_each_local_configuration do |config|
      block.call adapt_jdbc_config(config)
    end
  end
  
  private
  def adapt_jdbc_config(config)
    config.merge 'adapter' => config['adapter'].sub(/^jdbc/, '')
  end
  
end

ActiveRecord::Tasks::MySQLDatabaseTasks.class_eval do

  def error_class
    ActiveRecord::JDBCError
  end

end

#namespace :db do
#
#  def create_database(config)
#    begin
#      ActiveRecord::Base.establish_connection(config)
#      ActiveRecord::Base.connection
#    rescue
#      begin
#        if url = config['url'] and url =~ /^(.*(?<!\/)\/)(?=\w)/
#          url = $1
#        end
#
#        ActiveRecord::Base.establish_connection(config.merge({'database' => nil, 'url' => url}))
#        ActiveRecord::Base.connection.create_database(config['database'], config)
#        ActiveRecord::Base.establish_connection(config)
#      rescue => e
#        raise e if config['adapter'] && config['adapter'] !~ /mysql|postgresql|sqlite/
#        ActiveRecord::Tasks::DatabaseTasks.create_current
#      end
#    end
#  end
#
#  def drop_database(config = nil)
#    ActiveRecord::Tasks::DatabaseTasks.drop_current
#  end
#
#end