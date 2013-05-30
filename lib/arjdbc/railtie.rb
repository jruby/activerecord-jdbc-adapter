require 'rails/railtie'

module ArJdbc
  class Railtie < ::Rails::Railtie
    rake_tasks do
      if defined? ActiveRecord::Railtie # only if AR being used
        load File.expand_path('tasks.rb', File.dirname(__FILE__))
      end
    end
  end
end
