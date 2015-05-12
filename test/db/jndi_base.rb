
# FS based JNDI impl borrowed from tomcat :
#load 'test/jars/tomcat-juli.jar'
#load 'test/jars/tomcat-catalina.jar'

java.lang.System.set_property(
    javax.naming.Context::INITIAL_CONTEXT_FACTORY,
    'org.apache.naming.java.javaURLContextFactory'
)
java.lang.System.set_property(
    javax.naming.Context::URL_PKG_PREFIXES,
    'org.apache.naming'
)

init_context = javax.naming.InitialContext.new
begin
  init_context.create_subcontext 'jdbc'
rescue javax.naming.NameAlreadyBoundException
end
