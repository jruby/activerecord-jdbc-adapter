require 'db/jndi_base'

JNDI_DERBY_CONFIG = { :adapter => 'jdbc', :jndi => 'jdbc/DerbyDB' }

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  JNDI_DERBY_CONFIG[:prepared_statements] = ps
end

require 'jdbc/derby'
Jdbc::Derby.load_driver

data_source = org.apache.derby.jdbc.EmbeddedDataSource.new
data_source.database_name = "memory:DerbyDB-JNDI"
data_source.create_database = "create"
data_source.user = "sa"
data_source.password = ""

javax.naming.InitialContext.new.bind JNDI_DERBY_CONFIG[:jndi], data_source
