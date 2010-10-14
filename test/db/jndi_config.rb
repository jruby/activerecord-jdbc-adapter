require 'fileutils'
require 'arjdbc'

JNDI_CONFIG = {
  :adapter => "jdbc",
  :jndi => 'jdbc/derbydb'
}

# To test JNDI, grab fscontext-1_2-beta3.zip from
# http://java.sun.com/products/jndi/downloads/index.html
# and put fscontext.jar and providerutil.jar in test/
require 'test/fscontext.jar'
require 'test/providerutil.jar'
require 'jdbc/derby'

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

ic = InitialContext.new
ic.rebind(JNDI_CONFIG[:jndi],
          org.apache.derby.jdbc.EmbeddedDataSource.new.tap {|ds|
            ds.database_name = "derby-testdb-jndi"
            ds.create_database = "create"
            ds.user = "sa"
            ds.password = ""})


ActiveRecord::Base.establish_connection(JNDI_CONFIG)
