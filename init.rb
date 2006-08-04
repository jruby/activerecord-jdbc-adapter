RAILS_CONNECTION_ADAPTERS << 'jdbc'
require 'active_record/connection_adapters/jdbc_adapter'

[:initialize_database, :initialize_framework_logging, :initialize_framework_settings].each do |cmd|
  Rails::Initializer.run(cmd) do |config|
    config.frameworks = [:active_record]
  end
end
