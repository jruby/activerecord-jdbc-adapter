package arjdbc.sybase;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import arjdbc.jdbc.RubyJdbcConnection;

public class SybaseASERubyJdbcConnection extends RubyJdbcConnection {

	// The JDBC JavaDoc for the java.sql.Statement#getGeneratedKeys() method states that in case an
	// empty ResultSet is returned from the database, it should be returned as well from the method call.
	// Sybase ASE's jConnect family of JDBC drivers however follow a different behavior here:
	// although connection.getMetaData().supportsGetGeneratedKeys() returns true, the call to the
	// getGeneratedKeys() method may throw java.sql.SQLException in the case of empty ResultSet.
	
	private static final String SYBASE_DRIVER_GENERATEDKEYS_ERRORCODE = "JZ0NK";

	protected SybaseASERubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
		super(runtime, metaClass);		
	}
	
	public static RubyClass createSybaseASEJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).defineClassUnder("SybaseASEJdbcConnection",
                jdbcConnection, SYBASE_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(SybaseASERubyJdbcConnection.class);

        return clazz;
    }

    private static ObjectAllocator SYBASE_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new SybaseASERubyJdbcConnection(runtime, klass);
        }
    };   
    
    @Override    
    public IRubyObject insert_bind(ThreadContext context, IRubyObject[] args) throws SQLException { 
    	try {
    		return super.insert_bind(context, args);
    	} catch (SQLException sqlExc) {   
    		// Check the special case when the jConnect JDBC driver for Sybase complains about the getGeneratedKeys() invocation.
    		// Proceed normally in this case (consider empty ResultSet returned); otherwise rethrow the exception.
    		if (sqlExc.getMessage().contains(SYBASE_DRIVER_GENERATEDKEYS_ERRORCODE)) {
    			return context.getRuntime().getNil();
    		} else {
    			throw sqlExc;
    		}
    	}
    }
    
    @Override    
    public IRubyObject execute_insert(ThreadContext context, IRubyObject sql) throws SQLException {    	
    	try {    		
    		return super.execute_insert(context, sql);
    	} catch (SQLException sqlExc) {  
    		// Check the special case when the jConnect JDBC driver for Sybase complains about the getGeneratedKeys() invocation.
    		// Proceed normally in this case (consider empty ResultSet returned); otherwise rethrow the exception.
    		if (sqlExc.getMessage().contains(SYBASE_DRIVER_GENERATEDKEYS_ERRORCODE)) {
    			return context.getRuntime().getNil();
    		} else {
    			throw sqlExc;
    		}	
    	} catch (RaiseException rExc) {
    		// It is possible to have the driver exception wrapped in org.jruby.exceptions.RaiseException
    		if (rExc.getMessage().contains(SYBASE_DRIVER_GENERATEDKEYS_ERRORCODE)) {
    			return context.getRuntime().getNil();
    		} else {
    			throw rExc;
    		}	
    	}
    }
    
    @Override
    protected IRubyObject unmarshalKeysOrUpdateCount(ThreadContext context, Connection c, Statement stmt) throws SQLException {    	
    	try {
    		return super.unmarshalKeysOrUpdateCount(context, c, stmt);
    	} catch (SQLException sqlExc){    	
    		// Check the special case when the jConnect JDBC driver for Sybase complains about the getGeneratedKeys() invocation.
    		// Proceed normally in this case; otherwise rethrow the exception.
    		if (sqlExc.getMessage().contains(SYBASE_DRIVER_GENERATEDKEYS_ERRORCODE)) {
    			return context.getRuntime().newFixnum(stmt.getUpdateCount());
    		} else {
    			throw sqlExc;
    		}	
    	}
    }
}