require 'arjdbc'
require 'jdbc_common'

JNDI_POOLED_CONFIG = {
  :adapter => 'jdbc', :jndi => 'jdbc/PooledDerbyDB'
}

# FS based JNDI impl borrowed from tomcat :
load 'test/jars/tomcat-juli.jar'
load 'test/jars/tomcat-catalina.jar'

java.lang.System.set_property(
    javax.naming.Context::INITIAL_CONTEXT_FACTORY,
    'org.apache.naming.java.javaURLContextFactory'
)
java.lang.System.set_property(
    javax.naming.Context::URL_PKG_PREFIXES,
    'org.apache.naming'
)

require 'jdbc/derby'
Jdbc::Derby.load_driver

data_source = org.apache.derby.jdbc.EmbeddedConnectionPoolDataSource.new
data_source.database_name = "memory:PooledDerbyDB-JNDI"
data_source.create_database = "create"
data_source.user = "sa"
data_source.password = ""

init_context = javax.naming.InitialContext.new
begin
  init_context.create_subcontext 'jdbc'
rescue javax.naming.NameAlreadyBoundException
end
init_context.bind JNDI_POOLED_CONFIG[:jndi], data_source