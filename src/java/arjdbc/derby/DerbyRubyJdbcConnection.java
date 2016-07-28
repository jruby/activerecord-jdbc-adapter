/*
 * The MIT License
 *
 * Copyright 2013 Karol Bucek.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package arjdbc.derby;

import arjdbc.jdbc.Callable;
import arjdbc.jdbc.DriverWrapper;
import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 * ArJdbc::DerbyJdbcConnection
 *
 * @author kares
 */
public class DerbyRubyJdbcConnection extends RubyJdbcConnection {
    private static final long serialVersionUID = 4809475910953623325L;

    public DerbyRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createDerbyJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime). // ActiveRecord::ConnectionAdapters
            defineClassUnder("DerbyJdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(DerbyRubyJdbcConnection.class);
        return clazz;
    }

    public static RubyClass load(final Ruby runtime) {
        RubyClass jdbcConnection = getJdbcConnection(runtime);
        return createDerbyJdbcConnectionClass(runtime, jdbcConnection);
    }

    protected static ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new DerbyRubyJdbcConnection(runtime, klass);
        }
    };

    @Override
    protected DriverWrapper newDriverWrapper(final ThreadContext context, final String driver) {
        DriverWrapper driverWrapper = super.newDriverWrapper(context, driver);

        final java.sql.Driver jdbcDriver = driverWrapper.getDriverInstance();
        if ( jdbcDriver.getClass().getName().startsWith("org.apache.derby.") ) {
            final int major = jdbcDriver.getMajorVersion();
            final int minor = jdbcDriver.getMinorVersion();
            if ( major < 10 || ( major == 10 && minor < 5 ) ) {
                final RubyClass errorClass = getConnectionNotEstablished(context.runtime);
                throw new RaiseException(context.runtime, errorClass,
                    "adapter requires Derby >= 10.5 got: " + major + "." + minor + "", false);
            }
            if ( major == 10 && minor < 8 ) { // 10.8 ~ supports JDBC 4.1
                // config[:connection_alive_sql] ||= 'SELECT 1 FROM SYS.SYSSCHEMAS FETCH FIRST 1 ROWS ONLY'
                setConfigValueIfNotSet(context, "connection_alive_sql", // FROM clause mandatory
                    context.runtime.newString("SELECT 1 FROM SYS.SYSSCHEMAS FETCH FIRST 1 ROWS ONLY"));
            }
        }

        return driverWrapper;
    }

    @JRubyMethod(name = "select?", required = 1, meta = true, frame = false)
    public static IRubyObject select_p(final ThreadContext context,
        final IRubyObject self, final IRubyObject sql) {
        if ( isValues(sql.convertToString()) ) {
            return context.getRuntime().newBoolean( true );
        }
        return arjdbc.jdbc.RubyJdbcConnection.select_p(context, self, sql);
    }

    // Derby supports 'stand-alone' VALUES expressions
    private static final byte[] VALUES = new byte[]{ 'v','a','l','u', 'e', 's' };

    private static boolean isValues(final RubyString sql) {
        final ByteList sqlBytes = sql.getByteList();
        return startsWithIgnoreCase(sqlBytes, VALUES);
    }

    @JRubyMethod(name = {"identity_val_local", "last_insert_id"})
    public IRubyObject identity_val_local(final ThreadContext context)
        throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                PreparedStatement statement = null; ResultSet genKeys = null;
                try {
                    statement = connection.prepareStatement("values IDENTITY_VAL_LOCAL()");
                    genKeys = statement.executeQuery();
                    return doMapGeneratedKeys(context.getRuntime(), genKeys, true);
                }
                catch (final SQLException e) {
                    debugMessage(context.runtime, "failed to get generated keys: ", e);
                    throw e;
                }
                finally { close(genKeys); close(statement); }
            }
        });
    }

    @Override
    protected boolean supportsGeneratedKeys(final Connection connection) throws SQLException {
        return true; // driver reports false from supportsGetGeneratedKeys()
    }

    @Override
    protected IRubyObject matchTables(final Ruby runtime,
            final Connection connection,
            final String catalog, String schemaPattern,
            final String tablePattern, final String[] types,
            final boolean checkExistsOnly) throws SQLException {
        if (schemaPattern != null && schemaPattern.equals("")) {
            schemaPattern = null; // Derby doesn't like empty-string schema name
        }
        return super.matchTables(runtime, connection, catalog, schemaPattern, tablePattern, types, checkExistsOnly);
    }

}
