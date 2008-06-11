# In order to run these tests, you need to have a few things on your
# classpath. First, you're going to need the Sun File system
# context. You can get that here: 
#
# http://java.sun.com/products/jndi/serviceproviders.html.  
#
# Make sure that you put both the fscontext.jar and the
# providerutil.jar on your classpath.  
#
# To support the connection pooling in the test, you'll need
# commons-dbcp, commons-pool, and commons-collections.
#
# Finally, you'll need the jdbc driver, which is derby, for this test.

require 'jdbc_common'
require 'db/jndi_config'

class DerbyJndiTest < Test::Unit::TestCase
  include SimpleTestMethods
  alias_method :setup_simple, :setup
  def setup
    ActiveRecord::Base.establish_connection({
        :jndi => 'jdbc/derbydb',
        :adapter => 'jdbc'})
    logger = Logger.new('jndi_test.log')
    logger.level = Logger::DEBUG
    ActiveRecord::Base.logger = logger
    setup_simple
  end
end

at_exit { 
  require 'fileutils'
  FileUtils.rm_rf 'derby-testdb'
}
