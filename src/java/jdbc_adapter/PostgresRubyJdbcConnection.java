/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package jdbc_adapter;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author enebo
 */
public class PostgresRubyJdbcConnection extends RubyJdbcConnection {
    protected PostgresRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createPostgresJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).defineClassUnder("PostgresJdbcConnection",
                jdbcConnection, POSTGRES_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(PostgresRubyJdbcConnection.class);

        return clazz;
    }

    private static ObjectAllocator POSTGRES_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new PostgresRubyJdbcConnection(runtime, klass);
        }
    };
}
