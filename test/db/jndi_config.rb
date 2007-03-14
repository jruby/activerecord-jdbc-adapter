require 'fileutils'
require 'active_record/connection_adapters/jdbc_adapter'

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
derby_ref = Reference.new('javax.sql.DataSource',
                          'org.apache.commons.dbcp.BasicDataSourceFactory',
                          nil)
derby_ref.add StringRefAddr.new('driverClassName', 
                                'org.apache.derby.jdbc.EmbeddedDriver')
derby_ref.add StringRefAddr.new('url', 
                                'jdbc:derby:derby-testdb;create=true')
derby_ref.add StringRefAddr.new('username', 'sa')
derby_ref.add StringRefAddr.new('password', '')

ic = InitialContext.new
ic.rebind("jdbc/derbydb", derby_ref)

