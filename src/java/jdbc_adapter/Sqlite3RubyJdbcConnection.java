/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package jdbc_adapter;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author enebo
 */
public class Sqlite3RubyJdbcConnection extends RubyJdbcConnection {
    protected Sqlite3RubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createSqlite3JdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).defineClassUnder("Sqlite3JdbcConnection",
                jdbcConnection, SQLITE3_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(Sqlite3RubyJdbcConnection.class);

        return clazz;
    }

    private static ObjectAllocator SQLITE3_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Sqlite3RubyJdbcConnection(runtime, klass);
        }
    };

    @Override
    protected IRubyObject tables(ThreadContext context, String catalog, String schemaPattern, String tablePattern, String[] types) {
        return (IRubyObject) withConnectionAndRetry(context, tableLookupBlock(context.getRuntime(), catalog, schemaPattern, tablePattern, types, true));
    }
}
