require 'logger'
ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::Base.logger.level = $DEBUG || ENV['DEBUG'] ? Logger::DEBUG : Logger::WARN
