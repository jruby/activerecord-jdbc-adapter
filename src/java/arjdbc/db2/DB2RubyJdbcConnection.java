/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2013 Karol Bucek <self@kares.org>
 * Copyright (c) 2006-2010 Nick Sieger <nick@nicksieger.com>
 * Copyright (c) 2006-2007 Ola Bini <ola.bini@gmail.com>
 * Copyright (c) 2008-2009 Thomas E Enebo <enebo@acm.org>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 ***** END LICENSE BLOCK *****/
package arjdbc.db2;

import arjdbc.jdbc.Callable;
import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 *
 * @author mikestone
 */
public class DB2RubyJdbcConnection extends RubyJdbcConnection {

    protected DB2RubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createDB2JdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).defineClassUnder("DB2JdbcConnection",
                jdbcConnection, DB2_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(DB2RubyJdbcConnection.class);

        return clazz;
    }

    private static ObjectAllocator DB2_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new DB2RubyJdbcConnection(runtime, klass);
        }
    };

    @JRubyMethod(name = "select?", required = 1, meta = true, frame = false)
    public static IRubyObject select_p(final ThreadContext context,
        final IRubyObject self, final IRubyObject sql) {
        if ( isValues(sql.convertToString()) ) {
            return context.getRuntime().newBoolean( true );
        }
        return arjdbc.jdbc.RubyJdbcConnection.select_p(context, self, sql);
    }

    // DB2 supports 'stand-alone' VALUES expressions
    private static final byte[] VALUES = new byte[]{ 'v','a','l','u', 'e', 's' };

    private static boolean isValues(final RubyString sql) {
        final ByteList sqlBytes = sql.getByteList();
        return startsWithIgnoreCase(sqlBytes, VALUES);
    }

    private static final String[] TABLE_TYPES = new String[] {
        "TABLE", "VIEW", "SYNONYM", "MATERIALIZED QUERY TABLE", "ALIAS"
    };

    @Override
    protected String[] getTableTypes() {
        return TABLE_TYPES;
    }

    @Override
    protected boolean databaseSupportsSchemas() {
        return true;
    }

    @JRubyMethod(name = {"identity_val_local", "last_insert_id"})
    public IRubyObject identity_val_local(final ThreadContext context)
        throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                PreparedStatement statement = null; ResultSet genKeys = null;
                try {
                    statement = connection.prepareStatement("VALUES IDENTITY_VAL_LOCAL()");
                    genKeys = statement.executeQuery();
                    return doMapGeneratedKeys(context.getRuntime(), genKeys, true);
                }
                catch (final SQLException e) {
                    debugMessage(context, "failed to get generated keys: " + e.getMessage());
                    throw e;
                }
                finally { close(genKeys); close(statement); }
            }
        });
    }

    // NOTE: this is non-sense or DB2 - but it has been originally implemented this way !
    //@JRubyMethod(name = {"identity_val_local", "last_insert_id"}, required = 1)
    private IRubyObject identity_val_local(final ThreadContext context, final IRubyObject table)
        throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null; ResultSet genKeys = null;
                try {
                    statement = connection.createStatement();
                    genKeys = statement.executeQuery("SELECT IDENTITY_VAL_LOCAL() FROM " + table);
                    return doMapGeneratedKeys(context.getRuntime(), genKeys, true);
                }
                catch (final SQLException e) {
                    debugMessage(context, "failed to get generated keys: " + e.getMessage());
                    throw e;
                }
                finally { close(genKeys); close(statement); }
            }
        });
    }

}
