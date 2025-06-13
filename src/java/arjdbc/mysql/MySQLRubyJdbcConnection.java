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
package arjdbc.mysql;

import arjdbc.jdbc.Callable;
import arjdbc.jdbc.DriverWrapper;
import arjdbc.jdbc.RubyJdbcConnection;
import arjdbc.util.DateTimeUtils;
import org.jruby.Ruby;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.SafePropertyAccessor;

import java.lang.reflect.InvocationTargetException;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;

import static org.jruby.api.Create.newEmptyString;
import static org.jruby.api.Create.newString;

/**
 *
 * @author nicksieger
 */
@org.jruby.anno.JRubyClass(name = "ActiveRecord::ConnectionAdapters::MySQLJdbcConnection")
public class MySQLRubyJdbcConnection extends RubyJdbcConnection {
    private static final long serialVersionUID = -8842614212147138733L;

    public MySQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createMySQLJdbcConnectionClass(ThreadContext context, RubyClass jdbcConnection) {
        return getConnectionAdapters(context).
                defineClassUnder(context, "MySQLJdbcConnection", jdbcConnection, ALLOCATOR).
                defineMethods(context, MySQLRubyJdbcConnection.class);
    }

    public static RubyClass load(final Ruby runtime) {
        var context = runtime.getCurrentContext();
        RubyClass jdbcConnection = getJdbcConnection(context);
        return createMySQLJdbcConnectionClass(context, jdbcConnection);
    }

    protected static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new MySQLRubyJdbcConnection(runtime, klass);
        }
    };

    @JRubyMethod
    public IRubyObject query(final ThreadContext context, final IRubyObject sql) throws SQLException {
        return execute_update(context, sql);
    }

    @JRubyMethod(name = { "full_version" })
    public IRubyObject db_version(final ThreadContext context) {
        return withConnection(context, (Callable<IRubyObject>) connection -> {
            final DatabaseMetaData metaData = connection.getMetaData();
            return newString(context, metaData.getDatabaseProductVersion());
        });
    }

    @Override
    protected DriverWrapper newDriverWrapper(final ThreadContext context, final String driver) {
        DriverWrapper driverWrapper = super.newDriverWrapper(context, driver);

        final java.sql.Driver jdbcDriver = driverWrapper.getDriverInstance();
        if ( jdbcDriver.getClass().getName().startsWith("com.mysql.jdbc.") ) {
            final int major = jdbcDriver.getMajorVersion();
            final int minor = jdbcDriver.getMinorVersion();
            if ( major < 5 ) {
                final RubyClass errorClass = getConnectionNotEstablished(context);
                throw context.runtime.newRaiseException(errorClass,
                        "MySQL adapter requires driver >= 5.0 got: " + major + "." + minor);
            }
            if ( major == 5 && minor < 1 ) { // need 5.1 for JDBC 4.0
                // lightweight validation query: "/* ping */ SELECT 1"
                setConfigValueIfNotSet(context, "connection_alive_sql", newString(context, "/* ping */ SELECT 1"));
            }
            driverAdapter = new MySQLDriverAdapter(); // short-circuit
        }
        else {
            driverAdapter = new DriverAdapter(); // short-circuit (MariaDB)
        }

        return driverWrapper;
    }

    @JRubyMethod(name = "ping")
    public RubyBoolean db_ping(final ThreadContext context) {
        final Connection connection = getConnection(true);
        if (connection == null) return context.fals;

        // NOTE: It seems only `connection.isValid(aliveTimeout)` is needed
        // for JDBC 4.0 and up. https://jira.mariadb.org/browse/CONJ-51

        return context.runtime.newBoolean(isConnectionValid(context, connection));
    }

    private static transient Class MYSQL_CONNECTION;
    private static transient Boolean MYSQL_CONNECTION_FOUND;

    private static boolean checkMySQLConnection(final Connection connection) {
        Class mysqlDriverIface = MYSQL_CONNECTION;
        if (mysqlDriverIface == null && MYSQL_CONNECTION_FOUND == null) {
            try {
                MYSQL_CONNECTION = Class.forName("com.mysql.jdbc.MySQLConnection", false, MySQLRubyJdbcConnection.class.getClassLoader());
                MYSQL_CONNECTION_FOUND = Boolean.TRUE;
            }
            catch (ClassNotFoundException ex) {
                MYSQL_CONNECTION_FOUND = Boolean.FALSE;
            }
            mysqlDriverIface = MYSQL_CONNECTION;
        }
        if (mysqlDriverIface == null) return false;
        try {
            return connection.isWrapperFor(mysqlDriverIface);
        }
        catch (SQLException ex) {
            return false;
        }
    }

    private boolean usingMySQLDriver() {
        return checkMySQLConnection(getConnection(true));
    }

    private transient DriverAdapter driverAdapter;

    // NOTE: currently un-used but we'll need it if we attempt to handle fast string extraction
    private DriverAdapter getDriverAdapter() {
        if (driverAdapter == null) {
            driverAdapter = usingMySQLDriver() ? new MySQLDriverAdapter() : new DriverAdapter();
        }
        return driverAdapter;
    }

    private class DriverAdapter { // sensible driver without quirks (MariaDB)
        // left in for encoding specific extraction from driver - would allow us 'fast' string byte[] extraction
    }

    private class MySQLDriverAdapter extends DriverAdapter { // Connector/J (bloated) 5.x version
        // left in for encoding specific extraction from driver - would allow us 'fast' string byte[] extraction
    }

    @Override
    protected boolean doExecute(final Statement statement, final String query) throws SQLException {
        return statement.execute(query, Statement.RETURN_GENERATED_KEYS);
    }

    @Override
    protected IRubyObject jdbcToRuby(final ThreadContext context, final Ruby runtime,
        final int column, final int type, final ResultSet resultSet) throws SQLException {
        if ( type == Types.BIT ) {
            final int value = resultSet.getInt(column);
            return resultSet.wasNull() ? context.nil : runtime.newFixnum(value);
        }
        return super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    @Override
    protected void setTimeParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {
        // MySQL's TIME supports fractional seconds up-to nano precision: .000000
        setTimestampParameter(context, connection, statement, index, value, attribute, type);
    }

    @Override
    protected IRubyObject timeToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException { // due MySQL's TIME precision (up to nanos)

        final Timestamp value = resultSet.getTimestamp(column);
        if ( value == null ) {
            return resultSet.wasNull() ? context.nil : newEmptyString(context);
        }

        if ( rawDateTime != null && rawDateTime) {
            return newString(context, DateTimeUtils.dummyTimeToString(value));
        }

        return DateTimeUtils.newDummyTime(context, value, getDefaultTimeZone(context));
    }

    @Override
    protected IRubyObject timestampToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {

        final Timestamp value;
        try {
            value = resultSet.getTimestamp(column);
        }
        catch (SQLException e) {
            if (e.getMessage().contains("HOUR_OF_DAY")) {
                return stringToRuby(context, runtime, resultSet, column);
            }
            else {
                throw e;
            }
        }
        if ( value == null ) {
            return resultSet.wasNull() ? context.nil : RubyString.newEmptyString(runtime);
        }

        if ( rawDateTime != null && rawDateTime) {
            return RubyString.newString(runtime, DateTimeUtils.timestampToString(value));
        }

        // NOTE: with 'raw' String AR's Type::DateTime does put the time in proper time-zone
        // while when returning a Time object it just adjusts usec (apply_seconds_precision)
        // yet for custom SELECTs to work (SELECT created_at ... ) and for compatibility we
        // should be returning Time (by default) - AR does this by adjusting mysql2/pg returns

        return DateTimeUtils.newTime(context, value, getDefaultTimeZone(context));
    }

    @Override
    protected IRubyObject streamToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final byte[] bytes = resultSet.getBytes(column);
        if ( bytes == null /* || resultSet.wasNull() */ ) return context.nil;
        return newString(context, bytes);
    }

    // MySQL does never storesUpperCaseIdentifiers() :
    // storesLowerCaseIdentifiers() depends on "lower_case_table_names" server variable

    @Override
    protected final String caseConvertIdentifierForRails(final Connection connection, final String value) {
        return value; // MySQL does not storesUpperCaseIdentifiers() :
    }

    private transient Boolean lowerCaseIdentifiers;

    @Override
    protected final String caseConvertIdentifierForJdbc(
        final Connection connection, final String value) throws SQLException {
        if ( value == null ) return null;
        Boolean lowerCase = lowerCaseIdentifiers;
        if (lowerCase == null) {
            lowerCase = lowerCaseIdentifiers = connection.getMetaData().storesLowerCaseIdentifiers();
        }
        return lowerCase ? value.toLowerCase() : value;
    }

    @Override
    protected Connection newConnection() throws RaiseException, SQLException {
        final Connection connection;
        try {
            connection = super.newConnection();
        }
        catch (SQLException ex) {
            int errorCode = ex.getErrorCode();
            // access denied, no database
            if (errorCode == 1044 || errorCode == 1049) throw newNoDatabaseError(ex);
            throw ex;
        }
        if ( doStopCleanupThread() ) shutdownCleanupThread();
        return connection;
    }

    private static Boolean stopCleanupThread;
    static {
        final String stopThread = SafePropertyAccessor.getProperty("arjdbc.mysql.stop_cleanup_thread");
        if ( stopThread != null ) stopCleanupThread = Boolean.parseBoolean(stopThread);
    }

    private static boolean doStopCleanupThread() throws SQLException {
        return stopCleanupThread != null && stopCleanupThread;
    }

    private static boolean cleanupThreadShutdown;

    @SuppressWarnings("unchecked")
    private static void shutdownCleanupThread() {
        if ( cleanupThreadShutdown ) return;
        try {
            Class threadClass = Class.forName("com.mysql.jdbc.AbandonedConnectionCleanupThread");
            threadClass.getMethod("shutdown").invoke(null);
        }
        catch (ClassNotFoundException e) {
            debugMessage(null, "missing MySQL JDBC cleanup thread ", e);
        }
        catch (NoSuchMethodException | SecurityException | IllegalAccessException e) {
            debugMessage(null, e);
        } catch (InvocationTargetException e) {
            debugMessage(null, e.getTargetException());
        } finally { cleanupThreadShutdown = true; }
    }

}
