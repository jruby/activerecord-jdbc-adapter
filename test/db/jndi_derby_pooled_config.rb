require 'db/jndi_base'

JNDI_DERBY_POOLED_CONFIG = { :adapter => 'jndi', :jndi => 'jdbc/PooledDerbyDB' }

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  JNDI_DERBY_POOLED_CONFIG[:prepared_statements] = ps
end

require 'jdbc/derby'
Jdbc::Derby.load_driver

data_source = org.apache.derby.jdbc.EmbeddedConnectionPoolDataSource.new
data_source.database_name = "memory:PooledDerbyDB-JNDI"
data_source.create_database = "create"
data_source.user = "sa"
data_source.password = ""

javax.naming.InitialContext.new.bind JNDI_DERBY_POOLED_CONFIG[:jndi], data_source
