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

import java.lang.reflect.Field;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Time;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.TimeZone;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyFloat;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
public class MySQLRubyJdbcConnection extends RubyJdbcConnection {

    protected MySQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    private static ObjectAllocator MYSQL_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new MySQLRubyJdbcConnection(runtime, klass);
        }
    };

    public static RubyClass createMySQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("MySQLJdbcConnection", jdbcConnection, MYSQL_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(MySQLRubyJdbcConnection.class);
        return clazz;
    }

    @Override
    protected boolean doExecute(final Statement statement, final String query)
        throws SQLException {
        return statement.execute(query, Statement.RETURN_GENERATED_KEYS);
    }

    @Override
    protected IRubyObject mapGeneratedKeysOrUpdateCount(final ThreadContext context,
        final Connection connection, final Statement statement) throws SQLException {
        final Ruby runtime = context.getRuntime();
        final IRubyObject key = mapGeneratedKeys(runtime, connection, statement);
        return ( key == null || key.isNil() ) ? runtime.newFixnum( statement.getUpdateCount() ) : key;
    }

    @Override
    protected IRubyObject jdbcToRuby(
        final ThreadContext context, final Ruby runtime,
        final int column, final int type, final ResultSet resultSet)
        throws SQLException {
        if ( Types.BOOLEAN == type || Types.BIT == type ) {
            final boolean value = resultSet.getBoolean(column);
            return resultSet.wasNull() ? runtime.getNil() : runtime.newFixnum(value ? 1 : 0);
        }
        return super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    @Override // can not use statement.setTimestamp( int, Timestamp, Calendar )
    protected void setTimestampParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {
        if ( value.isNil() ) statement.setNull(index, Types.TIMESTAMP);
        else {
            value = getTimeInDefaultTimeZone(context, value);
            if ( value instanceof RubyString ) { // yyyy-[m]m-[d]d hh:mm:ss[.f...]
                final Timestamp timestamp = Timestamp.valueOf( value.toString() );
                statement.setTimestamp( index, timestamp ); // assume local time-zone
            }
            else { // Time or DateTime ( ActiveSupport::TimeWithZone.to_time )
                final double time = adjustTimeFromDefaultZone(value);
                final RubyFloat timeValue = context.getRuntime().newFloat( time );
                statement.setTimestamp( index, convertToTimestamp(timeValue) );
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
            value = getTimeInDefaultTimeZone(context, value);
            if ( value instanceof RubyString ) {
                final Time time = Time.valueOf( value.toString() );
                statement.setTime( index, time ); // assume local time-zone
            }
            else { // Time or DateTime ( ActiveSupport::TimeWithZone.to_time )
                final double timeValue = adjustTimeFromDefaultZone(value);
                final Time time = new Time(( (long) timeValue ) * 1000); // millis
                // java.sql.Time is expected to be only up to second precision
                statement.setTime( index, time );
            }
        }
    }

    private static double adjustTimeFromDefaultZone(final IRubyObject value) {
        // Time's to_f is : ( millis * 1000 + usec ) / 1_000_000.0
        final double time = value.convertToFloat().getDoubleValue(); // to_f
        // NOTE: MySQL assumes default TZ thus need to adjust to match :
        final int offset = TimeZone.getDefault().getOffset((long) time * 1000);
        // Time's to_f is : ( millis * 1000 + usec ) / 1_000_000.0
        return time - ( offset / 1000.0 );
    }

    @Override
    protected IRubyObject indexes(final ThreadContext context, final String tableName, final String name, final String schemaName) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final Ruby runtime = context.getRuntime();
                final RubyModule indexDefinition = getIndexDefinition(runtime);
                final String jdbcTableName = caseConvertIdentifierForJdbc(connection, tableName);
                final String jdbcSchemaName = caseConvertIdentifierForJdbc(connection, schemaName);
                final IRubyObject rubyTableName = RubyString.newUnicodeString(
                    runtime, caseConvertIdentifierForJdbc(connection, tableName)
                );

                StringBuilder query = new StringBuilder("SHOW KEYS FROM ");
                if (jdbcSchemaName != null) {
                    query.append(jdbcSchemaName).append(".");
                }
                query.append(jdbcTableName);
                query.append(" WHERE key_name != 'PRIMARY'");

                final List<IRubyObject> indexes = new ArrayList<IRubyObject>();
                PreparedStatement statement = null;
                ResultSet keySet = null;

                try {
                    statement = connection.prepareStatement(query.toString());
                    keySet = statement.executeQuery();

                    String currentKeyName = null;

                    while ( keySet.next() ) {
                        final String keyName = caseConvertIdentifierForRails(connection, keySet.getString("key_name"));

                        if ( ! keyName.equals(currentKeyName) ) {
                            currentKeyName = keyName;

                            final boolean nonUnique = keySet.getBoolean("non_unique");

                            IRubyObject[] args = new IRubyObject[] {
                                rubyTableName, // table_name
                                RubyString.newUnicodeString(runtime, keyName), // index_name
                                runtime.newBoolean( ! nonUnique ), // unique
                                runtime.newArray(), // [] for column names, we'll add to that in just a bit
                                runtime.newArray() // lengths
                            };

                            indexes.add( indexDefinition.callMethod(context, "new", args) ); // IndexDefinition.new
                        }

                        IRubyObject lastIndexDef = indexes.isEmpty() ? null : indexes.get(indexes.size() - 1);
                        if (lastIndexDef != null) {
                            final String columnName = caseConvertIdentifierForRails(connection, keySet.getString("column_name"));
                            final int length = keySet.getInt("sub_part");
                            final boolean nullLength = keySet.wasNull();

                            lastIndexDef.callMethod(context, "columns").callMethod(context,
                                    "<<", RubyString.newUnicodeString(runtime, columnName));
                            lastIndexDef.callMethod(context, "lengths").callMethod(context,
                                    "<<", nullLength ? runtime.getNil() : runtime.newFixnum(length));
                        }
                    }

                    return runtime.newArray(indexes);
                }
                finally {
                    close(keySet);
                    close(statement);
                }
            }
        });
    }

    @Override
    protected String caseConvertIdentifierForRails(final Connection connection, final String value)
        throws SQLException {
        if ( value == null ) return null;
        return value; // MySQL does not storesUpperCaseIdentifiers() :
    }

    @Override
    protected Connection newConnection() throws RaiseException, SQLException {
        final Connection connection = super.newConnection();
        killCancelTimer(connection);
        return connection;
    }

    /**
     * HACK HACK HACK See http://bugs.mysql.com/bug.php?id=36565
     * MySQL's statement cancel timer can cause memory leaks, so cancel it
     * if we loaded MySQL classes from the same class-loader as JRuby
     *
     * NOTE: this will likely do nothing on a recent driver esp. since MySQL's
     * Connector/J supports JDBC 4.0 (Java 6+) which we now require at minimum
     */
    private void killCancelTimer(final Connection connection) {
        if (connection.getClass().getClassLoader() == getRuntime().getJRubyClassLoader()) {
            Field field = cancelTimerField();
            if ( field != null ) {
                java.util.Timer timer = null;
                try {
                    Connection unwrap = connection.unwrap(Connection.class);
                    // when failover is used (LoadBalancedMySQLConnection)
                    // we'll end up with a proxy returned not the real thing :
                    if ( Proxy.isProxyClass(unwrap.getClass()) ) return;
                    // connection likely: com.mysql.jdbc.JDBC4Connection
                    // or (for 3.0) super class: com.mysql.jdbc.ConnectionImpl
                    timer = (java.util.Timer) field.get( unwrap );
                }
                catch (SQLException e) {
                    debugMessage( e.toString() );
                }
                catch (IllegalAccessException e) {
                    debugMessage( e.toString() );
                }
                if ( timer != null ) timer.cancel();
            }
        }
    }

    private static Field cancelTimer = null;
    private static boolean cancelTimerChecked = false;

    private static Field cancelTimerField() {
        if ( cancelTimerChecked ) return cancelTimer;
        try {
            Class klass = Class.forName("com.mysql.jdbc.ConnectionImpl");
            Field field = klass.getDeclaredField("cancelTimer");
            field.setAccessible(true);
            synchronized(MySQLRubyJdbcConnection.class) {
                if ( cancelTimer == null ) cancelTimer = field;
            }
        }
        catch (ClassNotFoundException e) {
            debugMessage("INFO: missing MySQL JDBC connection impl: " + e);
        }
        catch (NoSuchFieldException e) {
            debugMessage("INFO: MySQL's cancel timer seems to have changed: " + e);
        }
        catch (SecurityException e) {
            debugMessage( e.toString() );
        }
        finally { cancelTimerChecked = true; }
        return cancelTimer;
    }

}
