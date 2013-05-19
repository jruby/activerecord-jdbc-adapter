namespace :db do

  namespace :create do
    task :all => :rails_env
  end

  namespace :drop do
    task :all => :environment
  end

  class << self
    alias_method :previous_create_database, :create_database
    alias_method :previous_drop_database, :drop_database
  end
  
  def create_database(config)
    begin
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection
    rescue
      begin
        if url = config['url'] and url =~ /^(.*(?<!\/)\/)(?=\w)/
          url = $1
        end

        ActiveRecord::Base.establish_connection(config.merge({'database' => nil, 'url' => url}))
        ActiveRecord::Base.connection.create_database(config['database'], config)
        ActiveRecord::Base.establish_connection(config)
      rescue => e
        raise e unless config['adapter'] =~ /mysql|postgresql|sqlite/
        previous_create_database(config.merge('adapter' => config['adapter'].sub(/^jdbc/, '')))
      end
    end
  end

  def drop_database(config)
    previous_drop_database(config.merge('adapter' => config['adapter'].sub(/^jdbc/, '')))
  end
  
end