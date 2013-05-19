require 'pathname'

module Rails
  class Configuration; end unless const_defined?(:Configuration)
  Configuration.class_eval do
    def root
      defined?(RAILS_ROOT) ? Pathname.new(RAILS_ROOT).realpath : raise("Rails.root not set")
    end
  end
  class Application
    def self.config
      @config ||= Configuration.new
    end
    def self.paths
      @paths ||= Hash.new { [] }
    end
  end
  def self.application
    Rails::Application
  end
  def self.configuration
    application.config
  end
  def self.root
    application && application.config.root
  end
  def self.env
    env = defined?(RAILS_ENV) ? RAILS_ENV : ( ENV["RAILS_ENV"] || "development" )
    ActiveSupport::StringInquirer.new(env)
  end
end