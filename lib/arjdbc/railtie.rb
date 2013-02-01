require 'rails/railtie'

module ArJdbc
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path('jdbc/rake_tasks.rb', File.dirname(__FILE__))
    end
  end
end
