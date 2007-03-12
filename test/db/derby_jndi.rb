require 'fileutils'
require 'active_record/connection_adapters/jndi_adapter'

System = java.lang.System
Context = javax.naming.Context
InitialContext = javax.naming.InitialContext
Reference = javax.naming.Reference
StringRefAddr = javax.naming.StringRefAddr
  
System.set_property(Context::INITIAL_CONTEXT_FACTORY,
                    'com.sun.jndi.fscontext.RefFSContextFactory')
project_path = File.expand_path(File.dirname(__FILE__) + '/../..')
jndi_dir = project_path + '/jndi_test'
jdbc_dir = jndi_dir + '/jdbc'
FileUtils.mkdir_p jdbc_dir unless File.exist?(jdbc_dir)

System.set_property(Context::PROVIDER_URL, "file://#{jndi_dir}")
reference = Reference.new('javax.sql.DataSource',
                          'org.apache.commons.dbcp.BasicDataSourceFactory',
                          nil)
reference.add StringRefAddr.new('driverClassName', 
                                'org.apache.derby.jdbc.EmbeddedDriver')
reference.add StringRefAddr.new('url', 
                                'jdbc:derby:derby-testdb;create=true')
reference.add StringRefAddr.new('username', 'sa')
reference.add StringRefAddr.new('password', '')
ic = InitialContext.new
ic.rebind("jdbc/testdb", reference)

require 'logger'

config = { 
  :adapter => 'jdbc',
  :jndi => 'jdbc/testdb',
  :driver => 'derby'
}
  
ActiveRecord::Base.establish_connection(config)
logger = Logger.new 'derby-jdbc.log'
logger.level = Logger::DEBUG
ActiveRecord::Base.logger = logger

at_exit { 
  require 'fileutils'
  FileUtils.rm_rf('derby-testdb')
  FileUtils.rm_rf(jndi_dir)
}
