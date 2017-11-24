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

import arjdbc.jdbc.DriverWrapper;
import arjdbc.jdbc.RubyJdbcConnection;
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
import java.util.TimeZone;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.joda.time.DateTime;
import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.RubyTime;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.SafePropertyAccessor;
import org.jruby.util.TypeConverter;
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
        else if ( type == Types.BINARY || type == Types.VARBINARY) {
            final byte[] bytes = resultSet.getBytes(column);
            if ( bytes == null || resultSet.wasNull() ) return context.nil;
            final ByteList byteList = new ByteList(bytes, false);
            return new RubyString(runtime, runtime.getString(), byteList);
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
            Class threadClass = Class.forName("com.mysql.jdbc.AbandonedConnectionCleanupThread");
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
