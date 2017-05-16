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

import arjdbc.jdbc.RubyJdbcConnection;
import arjdbc.jdbc.Callable;
import arjdbc.jdbc.DriverWrapper;
import arjdbc.util.DateTimeUtils;

import java.lang.reflect.InvocationTargetException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Time;
import java.sql.Timestamp;
import java.sql.Types;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyFixnum;
import org.jruby.RubyFloat;
import org.jruby.RubyInteger;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.SafePropertyAccessor;
import org.jruby.util.ByteList;

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

    public static RubyClass createMySQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("MySQLJdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(MySQLRubyJdbcConnection.class);
        return clazz;
    }

    public static RubyClass load(final Ruby runtime) {
        RubyClass jdbcConnection = getJdbcConnection(runtime);
        return createMySQLJdbcConnectionClass(runtime, jdbcConnection);
    }

    protected static ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new MySQLRubyJdbcConnection(runtime, klass);
        }
    };

    @Override
    protected DriverWrapper newDriverWrapper(final ThreadContext context, final String driver) {
        DriverWrapper driverWrapper = super.newDriverWrapper(context, driver);

        final java.sql.Driver jdbcDriver = driverWrapper.getDriverInstance();
        if ( jdbcDriver.getClass().getName().startsWith("com.mysql.jdbc.") ) {
            final int major = jdbcDriver.getMajorVersion();
            final int minor = jdbcDriver.getMinorVersion();
            if ( major < 5 ) {
                final RubyClass errorClass = getConnectionNotEstablished(context.runtime);
                throw new RaiseException(context.runtime, errorClass,
                    "MySQL adapter requires driver >= 5.0 got: " + major + "." + minor + "", false);
            }
            if ( major == 5 && minor < 1 ) { // need 5.1 for JDBC 4.0
                // lightweight validation query: "/* ping */ SELECT 1"
                setConfigValueIfNotSet(context, "connection_alive_sql", context.runtime.newString("/* ping */ SELECT 1"));
            }
        }

        return driverWrapper;
    }

    @Override
    protected boolean doExecute(final Statement statement, final String query)
        throws SQLException {
        return statement.execute(query, Statement.RETURN_GENERATED_KEYS);
    }

    @Override
    protected IRubyObject mapGeneratedKeysOrUpdateCount(final ThreadContext context,
        final Connection connection, final Statement statement) throws SQLException {
        final Ruby runtime = context.runtime;
        final IRubyObject key = mapGeneratedKeys(runtime, connection, statement);
        return ( key == null || key.isNil() ) ?
            RubyFixnum.newFixnum( runtime, statement.getUpdateCount() ) : key;
    }

    @Override
    protected IRubyObject jdbcToRuby(
        final ThreadContext context, final Ruby runtime,
        final int column, final int type, final ResultSet resultSet)
        throws SQLException {
        if ( type == Types.BIT ) {
            final int value = resultSet.getInt(column);
            return resultSet.wasNull() ? runtime.getNil() : runtime.newFixnum(value);
        }
        else if ( type == Types.BINARY || type == Types.VARBINARY) {
            final byte[] bytes = resultSet.getBytes(column);
            if ( bytes == null || resultSet.wasNull() ) return runtime.getNil();
            final ByteList byteList = new ByteList(bytes, false);
            return new RubyString(runtime, runtime.getString(), byteList);
        }
        return super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    @Override
    protected boolean useByteStrings() {
        final Boolean useByteStrings = byteStrings; // true by default :
        return useByteStrings == null ? true : useByteStrings.booleanValue();
    }

    /*
    @Override // optimized CLOBs
    protected IRubyObject readerToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        return bytesToUTF8String(context, runtime, resultSet, column);
    } */

    @Override // can not use statement.setTimestamp( int, Timestamp, Calendar )
    protected void setTimestampParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {
        if ( value.isNil() ) statement.setNull(index, Types.TIMESTAMP);
        else {
            value = DateTimeUtils.getTimeInDefaultTimeZone(context, value);
            if ( value instanceof RubyString ) { // yyyy-[m]m-[d]d hh:mm:ss[.f...]
                final Timestamp timestamp = Timestamp.valueOf( value.toString() );
                statement.setTimestamp( index, timestamp ); // assume local time-zone
            }
            else { // Time or DateTime ( ActiveSupport::TimeWithZone.to_time )
                final double time = DateTimeUtils.adjustTimeFromDefaultZone(value);
                final RubyFloat timeValue = context.runtime.newFloat( time );
                statement.setTimestamp( index, DateTimeUtils.convertToTimestamp(timeValue) );
            }
        }
    }

    @Override // can not use statement.setTime( int, Time, Calendar )
    protected void setTimeParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {
        if ( value.isNil() ) statement.setNull(index, Types.TIME);
        else {
            value = DateTimeUtils.getTimeInDefaultTimeZone(context, value);
            if ( value instanceof RubyString ) {
                final Time time = Time.valueOf( value.toString() );
                statement.setTime( index, time ); // assume local time-zone
            }
            else { // Time or DateTime ( ActiveSupport::TimeWithZone.to_time )
                final double timeValue = DateTimeUtils.adjustTimeFromDefaultZone(value);
                final Time time = new Time(( (long) timeValue ) * 1000); // millis
                // java.sql.Time is expected to be only up to second precision
                statement.setTime( index, time );
            }
        }
    }

    @Override
    protected final boolean isConnectionValid(final ThreadContext context, final Connection connection) {
        if ( connection == null ) return false;
        Statement statement = null;
        try {
            final RubyString aliveSQL = getAliveSQL(context);
            final RubyInteger aliveTimeout = getAliveTimeout(context);
            if ( aliveSQL != null ) {
                // expect a SELECT/CALL SQL statement
                statement = createStatement(context, connection);
                if (aliveTimeout != null) {
                    statement.setQueryTimeout((int) aliveTimeout.getLongValue()); // 0 - no timeout
                }
                statement.execute( aliveSQL.toString() );
                return true; // connection alive
            }
            else { // alive_sql nil (or not a statement we can execute)
                return connection.isValid(aliveTimeout == null ? 0 : (int) aliveTimeout.getLongValue()); // since JDBC 4.0
                // ... isValid(0) (default) means no timeout applied
            }
        }
        catch (Exception e) {
            debugMessage(context, "connection considered broken due: " + e.toString());
            return false;
        }
        catch (AbstractMethodError e) { // non-JDBC 4.0 driver
            warn( context,
                "WARN: driver does not support checking if connection isValid()" +
                " please make sure you're using a JDBC 4.0 compilant driver or" +
                " set `connection_alive_sql: ...` in your database configuration" );
            debugStackTrace(context, e);
            throw e;
        }
        finally { close(statement); }
    }

    @Override
    protected RubyArray indexes(final ThreadContext context,
        final String tableName, final String name, final String schemaName) {
        return withConnection(context, new Callable<RubyArray>() {
            public RubyArray call(final Connection connection) throws SQLException {
                final Ruby runtime = context.runtime;
                final RubyModule IndexDefinition = getIndexDefinition(runtime);
                final String jdbcTableName = caseConvertIdentifierForJdbc(connection, tableName);
                final String jdbcSchemaName = caseConvertIdentifierForJdbc(connection, schemaName);
                final RubyString rubyTableName = cachedString(
                    context, caseConvertIdentifierForJdbc(connection, tableName)
                );

                StringBuilder query = new StringBuilder(60).append("SHOW KEYS FROM ");
                if ( jdbcSchemaName != null ) query.append(jdbcSchemaName).append('.');
                query.append(jdbcTableName);
                query.append(" WHERE key_name != 'PRIMARY'");

                final RubyArray indexes = RubyArray.newArray(runtime, 8);
                PreparedStatement statement = null;
                ResultSet keySet = null;

                try {
                    statement = connection.prepareStatement(query.toString());
                    keySet = statement.executeQuery();

                    String currentKeyName = null;
                    RubyArray currentColumns = null;
                    RubyArray currentLengths = null;

                    while ( keySet.next() ) {
                        final String keyName = caseConvertIdentifierForRails(connection, keySet.getString("key_name"));

                        if ( ! keyName.equals(currentKeyName) ) {
                            currentKeyName = keyName;

                            final boolean nonUnique = keySet.getBoolean("non_unique");

                            IRubyObject[] args = new IRubyObject[] {
                                rubyTableName, // table_name
                                cachedString(context, keyName), // index_name
                                nonUnique ? runtime.getFalse() : runtime.getTrue(), // unique
                                currentColumns = RubyArray.newArray(runtime, 4), // columns
                                currentLengths = RubyArray.newArray(runtime, 4) // lengths
                            };

                            indexes.append( IndexDefinition.callMethod(context, "new", args) ); // IndexDefinition.new
                        }

                        if ( currentColumns != null ) {
                            final String columnName = caseConvertIdentifierForRails(connection, keySet.getString("column_name"));
                            final int length = keySet.getInt("sub_part");
                            final boolean nullLength = length == 0 && keySet.wasNull();

                            currentColumns.append( cachedString(context, columnName) );
                            currentLengths.append( nullLength ? context.nil : RubyFixnum.newFixnum(runtime, length) );
                        }
                    }

                    return indexes;
                }
                finally {
                    close(keySet);
                    close(statement);
                }
            }
        });
    }

    // MySQL does never storesUpperCaseIdentifiers() :
    // storesLowerCaseIdentifiers() depends on "lower_case_table_names" server variable

    @Override
    protected final String caseConvertIdentifierForRails(
        final Connection connection, final String value) throws SQLException {
        if ( value == null ) return null;
        return value;
    }

    @Override
    protected final String caseConvertIdentifierForJdbc(
        final Connection connection, final String value) throws SQLException {
        if ( value == null ) return null;
        if ( connection.getMetaData().storesLowerCaseIdentifiers() ) {
            return value.toLowerCase();
        }
        return value;
    }

    @Override
    protected Connection newConnection() throws RaiseException, SQLException {
        final Connection connection = super.newConnection();
        if ( doStopCleanupThread() ) shutdownCleanupThread();
        return connection;
    }

    private static Boolean stopCleanupThread;
    static {
        final String stopThread = SafePropertyAccessor.getProperty("arjdbc.mysql.stop_cleanup_thread");
        if ( stopThread != null ) stopCleanupThread = Boolean.parseBoolean(stopThread);
    }

    private static boolean doStopCleanupThread() throws SQLException {
        // TODO when refactoring default behavior to "stop" consider not doing so for JNDI
        return stopCleanupThread != null && stopCleanupThread.booleanValue();
    }

    private static boolean cleanupThreadShutdown;

    @SuppressWarnings("unchecked")
    private static void shutdownCleanupThread() {
        if ( cleanupThreadShutdown ) return;
        try {
            Class<?> threadClass = Class.forName("com.mysql.jdbc.AbandonedConnectionCleanupThread");
            threadClass.getMethod("shutdown").invoke(null);
        }
        catch (ClassNotFoundException e) {
            debugMessage("missing MySQL JDBC cleanup thread: " + e);
        }
        catch (NoSuchMethodException e) {
            debugMessage( e.toString() );
        }
        catch (IllegalAccessException e) {
            debugMessage( e.toString() );
        }
        catch (InvocationTargetException e) {
            debugMessage( e.getTargetException().toString() );
        }
        catch (SecurityException e) {
            debugMessage( e.toString() );
        }
        finally { cleanupThreadShutdown = true; }
    }

}
