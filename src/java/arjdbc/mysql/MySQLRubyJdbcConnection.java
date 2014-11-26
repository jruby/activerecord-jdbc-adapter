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
import arjdbc.util.DateTimeUtils;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Time;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.TimeZone;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.joda.time.DateTime;
import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyInteger;
import org.jruby.RubyString;
import org.jruby.RubyTime;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.TypeConverter;

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

    protected static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new MySQLRubyJdbcConnection(runtime, klass);
        }
    };

    @JRubyMethod
    public IRubyObject query(final ThreadContext context, final IRubyObject sql) throws SQLException {
        final String query = sql.convertToString().getUnicodeValue(); // sql
        return executeUpdate(context, query, false);
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

    @Override // can not use statement.setTimestamp( int, Timestamp, Calendar )
    protected void setTimestampParameter(ThreadContext context, Connection connection, PreparedStatement statement,
        int index, IRubyObject value, IRubyObject column, int type) throws SQLException {
        value = callMethod(context, "time_in_default_timezone", value);
        TypeConverter.checkType(context, value, context.runtime.getTime());
        setTimestamp(statement, index, (RubyTime) value, type);
    }

    @Override
    protected void setTimeParameter(ThreadContext context, Connection connection, PreparedStatement statement,
        int index, IRubyObject value, IRubyObject column, int type) throws SQLException {
        setTimestampParameter(context, connection, statement, index, value, column, type);
    }

//    @Override
//    protected void setTimestampParameter(final ThreadContext context,
//        final Connection connection, final PreparedStatement statement,
//        final int index, IRubyObject value,
//        final IRubyObject column, final int type) throws SQLException {
//        if ( value.isNil() ) statement.setNull(index, Types.TIMESTAMP);
//        else {
//            value = DateTimeUtils.getTimeInDefaultTimeZone(context, value);
//            if ( value instanceof RubyString ) { // yyyy-[m]m-[d]d hh:mm:ss[.f...]
//                final Timestamp timestamp = Timestamp.valueOf( value.toString() );
//                statement.setTimestamp( index, timestamp ); // assume local time-zone
//            }
//            else { // Time or DateTime ( ActiveSupport::TimeWithZone.to_time )
//                final double time = DateTimeUtils.adjustTimeFromDefaultZone(value);
//                final RubyFloat timeValue = context.runtime.newFloat( time );
//                statement.setTimestamp( index, DateTimeUtils.convertToTimestamp(timeValue) );
//            }
//        }
//    }
//
//    @Override // can not use statement.setTime( int, Time, Calendar )
//    protected void setTimeParameter(final ThreadContext context,
//        final Connection connection, final PreparedStatement statement,
//        final int index, IRubyObject value,
//        final IRubyObject column, final int type) throws SQLException {
//        if ( value.isNil() ) statement.setNull(index, Types.TIME);
//        else {
//            value = DateTimeUtils.getTimeInDefaultTimeZone(context, value);
//            if ( value instanceof RubyString ) {
//                final Time time = Time.valueOf( value.toString() );
//                statement.setTime( index, time ); // assume local time-zone
//            }
//            else { // Time or DateTime ( ActiveSupport::TimeWithZone.to_time )
//                final double timeValue = DateTimeUtils.adjustTimeFromDefaultZone(value);
//                final Time time = new Time(( (long) timeValue ) * 1000); // millis
//                // java.sql.Time is expected to be only up to second precision
//                statement.setTime( index, time );
//            }
//        }
//    }


    // FIXME: we should detect adapter and not do this timezone offset calculation is it is jdbc version 6+.
    private void setTimestamp(PreparedStatement statement, int index, RubyTime value, int type) throws SQLException {
        DateTime dateTime = value.getDateTime();
        int offset = TimeZone.getDefault().getOffset(dateTime.getMillis()); // JDBC <6.x ignores time zone info (we adjust manually).
        Timestamp timestamp = new Timestamp(dateTime.getMillis() - offset);

        // 1942-11-30T01:02:03.123_456
        if (type != Types.DATE && value.getNSec() >= 0) timestamp.setNanos((int) (timestamp.getNanos() + value.getNSec()));

        statement.setTimestamp(index, timestamp);
    }

    // FIXME: I think we can unify this back to main adapter code since previous conflict involved not using
    // the raw string return type and not the extra formatting logic.
    @Override
    protected IRubyObject timeToRuby(ThreadContext context, Ruby runtime, ResultSet resultSet, int column) throws SQLException {
        Time value = resultSet.getTime(column);

        if (value == null) return resultSet.wasNull() ? context.nil : runtime.newString();

        String strValue = value.toString();

        // If time is column type but that time had a precision which included
        // nanoseconds we used timestamp to save the data.  Since this is conditional
        // we grab data a second time as a timestamp to look for nsecs.
        Timestamp nsecTimeHack = resultSet.getTimestamp(column);
        if (nsecTimeHack.getNanos() != 0) {
            strValue = String.format("%s.%09d", strValue, nsecTimeHack.getNanos());
        }

        return RubyString.newUnicodeString(runtime,strValue);
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
        return lowerCase.booleanValue() ? value.toLowerCase() : value;
    }

    @Override
    protected Connection newConnection() throws RaiseException, SQLException {
        final Connection connection = super.newConnection();
        if ( doStopCleanupThread() ) shutdownCleanupThread();
        if ( doKillCancelTimer(connection) ) killCancelTimer(connection);
        return connection;
    }

    private static Boolean stopCleanupThread;
    static {
        final String stopThread = System.getProperty("arjdbc.mysql.stop_cleanup_thread");
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
            Class threadClass = Class.forName("com.mysql.jdbc.AbandonedConnectionCleanupThread");
            threadClass.getMethod("shutdown").invoke(null);
        }
        catch (ClassNotFoundException e) {
            debugMessage("ArJdbc: missing MySQL JDBC cleanup thread: " + e);
        }
        catch (NoSuchMethodException e) {
            debugMessage("ArJdbc: " + e);
        }
        catch (IllegalAccessException e) {
            debugMessage("ArJdbc: " + e);
        }
        catch (InvocationTargetException e) {
            debugMessage("ArJdbc: " + e.getTargetException());
        }
        catch (SecurityException e) {
            debugMessage("ArJdbc: " + e);
        }
        finally { cleanupThreadShutdown = true; }
    }

    private static Boolean killCancelTimer;
    static {
        final String killTimer = System.getProperty("arjdbc.mysql.kill_cancel_timer");
        if ( killTimer != null ) killCancelTimer = Boolean.parseBoolean(killTimer);
    }

    private static boolean doKillCancelTimer(final Connection connection) throws SQLException {
        if ( killCancelTimer == null ) {
            synchronized (MySQLRubyJdbcConnection.class) {
                final String version = connection.getMetaData().getDriverVersion();
                if ( killCancelTimer == null ) {
                    String regex = "mysql\\-connector\\-java-(\\d)\\.(\\d)\\.(\\d+)";
                    Matcher match = Pattern.compile(regex).matcher(version);
                    if ( match.find() ) {
                        final int major = Integer.parseInt( match.group(1) );
                        final int minor = Integer.parseInt( match.group(2) );
                        if ( major < 5 || ( major == 5 && minor <= 1 ) ) {
                            final int patch = Integer.parseInt( match.group(3) );
                            killCancelTimer = patch < 11;
                        }
                    }
                    else {
                        killCancelTimer = Boolean.FALSE;
                    }
                }
            }
        }
        return killCancelTimer;
    }

    /**
     * HACK HACK HACK See http://bugs.mysql.com/bug.php?id=36565
     * MySQL's statement cancel timer can cause memory leaks, so cancel it
     * if we loaded MySQL classes from the same class-loader as JRuby
     *
     * NOTE: MySQL Connector/J 5.1.11 (2010-01-21) fixed the issue !
     */
    private void killCancelTimer(final Connection connection) {
        final Ruby runtime = getRuntime();
        if (connection.getClass().getClassLoader() == runtime.getJRubyClassLoader()) {
            final Field field = cancelTimerField(runtime);
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

    private Field cancelTimerField(final Ruby runtime) {
        if ( cancelTimerChecked ) return cancelTimer;
        final String name = "com.mysql.jdbc.ConnectionImpl";
        try {
            Class<?> klass = runtime.getJavaSupport().loadJavaClass(name);
            Field field = klass.getDeclaredField("cancelTimer");
            field.setAccessible(true);
            synchronized(MySQLRubyJdbcConnection.class) {
                if ( cancelTimer == null ) cancelTimer = field;
            }
        }
        catch (ClassNotFoundException e) {
            debugMessage("ArJdbc: missing MySQL JDBC connection impl: " + e);
        }
        catch (NoSuchFieldException e) {
            debugMessage("ArJdbc: MySQL's cancel timer seems to have changed: " + e);
        }
        catch (SecurityException e) {
            debugMessage("ArJdbc: " + e);
        }
        finally { cancelTimerChecked = true; }
        return cancelTimer;
    }

}
