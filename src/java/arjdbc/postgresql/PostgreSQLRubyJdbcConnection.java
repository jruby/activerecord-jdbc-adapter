/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2014 Karol Bucek <self@kares.org>
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
package arjdbc.postgresql;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.math.BigDecimal;
import java.sql.Array;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyFixnum;
import org.jruby.RubyFloat;
import org.jruby.RubyIO;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

import arjdbc.jdbc.DriverWrapper;
import arjdbc.util.DateTimeUtils;

/**
 *
 * @author enebo
 */
@org.jruby.anno.JRubyClass(name = "ActiveRecord::ConnectionAdapters::PostgreSQLJdbcConnection")
public class PostgreSQLRubyJdbcConnection extends arjdbc.jdbc.RubyJdbcConnection {
    private static final long serialVersionUID = 7235537759545717760L;

    public PostgreSQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createPostgreSQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("PostgreSQLJdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(PostgreSQLRubyJdbcConnection.class);
        return clazz;
    }

    public static RubyClass load(final Ruby runtime) {
        RubyClass jdbcConnection = getJdbcConnection(runtime);
        return createPostgreSQLJdbcConnectionClass(runtime, jdbcConnection);
    }

    protected static ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new PostgreSQLRubyJdbcConnection(runtime, klass);
        }
    };

    @Override
    protected DriverWrapper newDriverWrapper(final ThreadContext context, final String driver) {
        DriverWrapper driverWrapper = super.newDriverWrapper(context, driver);

        final java.sql.Driver jdbcDriver = driverWrapper.getDriverInstance();
        if ( jdbcDriver.getClass().getName().startsWith("org.postgresql.") ) {
            try { // public static String getVersion()
                final String version = (String) // "PostgreSQL 9.2 JDBC4 (build 1002)"
                    jdbcDriver.getClass().getMethod("getVersion").invoke(null);
                if ( version != null && version.indexOf("JDBC3") >= 0 ) {
                    // config[:connection_alive_sql] ||= 'SELECT 1'
                    setConfigValueIfNotSet(context, "connection_alive_sql", context.runtime.newString("SELECT 1"));
                }
            }
            catch (NoSuchMethodException e) { }
            catch (SecurityException e) { }
            catch (IllegalAccessException e) { }
            catch (InvocationTargetException e) { }
        }

        return driverWrapper;
    }

    final DriverImplementation driverImplementation = new PGDriverImplementation(); // currently no other supported

    DriverImplementation driverImplementation() { return driverImplementation; }

    // enables testing if the bug is fixed (please run our test-suite)
    // using `rake test_postgresql JRUBY_OPTS="-J-Darjdbc.postgresql.generated_keys=true"`
    protected static final boolean generatedKeys;
    static {
        String genKeys = System.getProperty("arjdbc.postgresql.generated_keys");
        if ( genKeys == null ) { // @deprecated system property name :
            genKeys = System.getProperty("arjdbc.postgresql.generated.keys");
        }
        generatedKeys = Boolean.parseBoolean(genKeys);
    }

    @Override
    protected IRubyObject mapGeneratedKeys(
        final Ruby runtime, final Connection connection,
        final Statement statement, final Boolean singleResult)
        throws SQLException {
        // NOTE: PostgreSQL driver supports generated keys but does not work
        // correctly for all cases e.g. for tables whene no keys are generated
        // during an INSERT getGeneratedKeys return all inserted rows instead
        // of an empty result set ... thus disabled until issue is resolved !
        if ( ! generatedKeys ) return null; // not supported
        // NOTE: generated-keys is implemented by the Postgre's JDBC driver by
        // adding a "RETURNING" suffix after the executeUpdate passed query ...
        return super.mapGeneratedKeys(runtime, connection, statement, singleResult);
    }

    // storesMixedCaseIdentifiers() return false;
    // storesLowerCaseIdentifiers() return true;
    // storesUpperCaseIdentifiers() return false;

    @Override
    protected final String caseConvertIdentifierForRails(final Connection connection, final String value)
        throws SQLException {
        return value;
    }

    @Override
    protected final String caseConvertIdentifierForJdbc(final Connection connection, final String value)
        throws SQLException {
        return value;
    }

    @Override
    protected final Connection newConnection() throws SQLException {
        return driverImplementation().newConnection( getConnectionFactory().newConnection() );
    }

    @Override // due statement.setNull(index, Types.BLOB) not working :
    // org.postgresql.util.PSQLException: ERROR: column "sample_binary" is of type bytea but expression is of type oid
    protected void setBlobParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final Object value,
        final IRubyObject column, final int type) throws SQLException {
        if ( value instanceof IRubyObject ) {
            setBlobParameter(context, connection, statement, index, (IRubyObject) value, column, type);
        }
        else {
            if ( value == null ) statement.setNull(index, Types.BINARY);
            else {
                statement.setBinaryStream(index, (InputStream) value);
            }
        }
    }

    @Override // due statement.setNull(index, Types.BLOB) not working :
    // org.postgresql.util.PSQLException: ERROR: column "sample_binary" is of type bytea but expression is of type oid
    protected void setBlobParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {
        if ( value.isNil() ) {
            statement.setNull(index, Types.BINARY);
        }
        else {
            if ( value instanceof RubyIO ) { // IO/File
                statement.setBinaryStream(index, ((RubyIO) value).getInStream());
            }
            else { // should be a RubyString
                final ByteList blob = value.asString().getByteList();
                statement.setBinaryStream(index,
                    new ByteArrayInputStream(blob.unsafeBytes(), blob.getBegin(), blob.getRealSize()),
                    blob.getRealSize() // length
                );
            }
        }
    }

    @Override // to handle infinity timestamp values
    protected void setTimestampParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {

        if ( ! driverImplementation().setTimestampParameter(context, connection, statement, index, value, column, type) ) {
            super.setTimestampParameter(context, connection, statement, index, value, column, type);
        }
    }

    @Override
    protected void setStringParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {

        if ( ! driverImplementation().setStringParameter(context, connection, statement, index, value, column, type) ) {
            super.setStringParameter(context, connection, statement, index, value, column, type);
        }
    }

    static int oid(final ThreadContext context, final IRubyObject column) {
        // our column convention :
        IRubyObject oid = column.getInstanceVariables().getInstanceVariable("@oid");
        if ( oid == null || oid.isNil() ) { // only for user instantiated Column
            throw new IllegalStateException("missing @oid for column: " + column.inspect());
        }
        return RubyFixnum.fix2int(oid);
    }

    @Override
    protected void setObjectParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, Object value,
        final IRubyObject column, final int type) throws SQLException {

        if ( ! driverImplementation().setObjectParameter(context, connection, statement, index, value, column, type) ) {
            super.setObjectParameter(context, connection, statement, index, value, column, type);
        }
    }

    @Override
    protected String resolveArrayBaseTypeName(final ThreadContext context,
        final Object value, final IRubyObject column, final int type) {
        String sqlType = column.callMethod(context, "sql_type").toString();
        if ( sqlType.startsWith("character varying") ) return "text";
        final int index = sqlType.indexOf('('); // e.g. "character varying(255)"
        if ( index > 0 ) sqlType = sqlType.substring(0, index);
        return sqlType;
    }

    //private static final int HSTORE_TYPE = 100000 + 1111;

    @Override
    protected int jdbcTypeFor(final ThreadContext context, final Ruby runtime,
        final IRubyObject column, final Object value) throws SQLException {
        // NOTE: likely wrong but native adapters handles this thus we should
        // too - used from #table_exists? `binds << [ nil, schema ] if schema`
        if ( column == null || column.isNil() ) return Types.VARCHAR; // assume type == :string
        final int type = super.jdbcTypeFor(context, runtime, column, value);
        /*
        if ( type == Types.OTHER ) {
            final IRubyObject columnType = column.callMethod(context, "type");
            if ( "hstore" == (Object) columnType.asJavaString() ) {
                return HSTORE_TYPE;
            }
        } */
        return type;
    }

    /**
     * Override jdbcToRuby type conversions to handle infinite timestamps.
     * Handing timestamp off to ruby as string so adapter can perform type
     * conversion to timestamp
     */
    @Override
    protected IRubyObject jdbcToRuby(
        final ThreadContext context, final Ruby runtime,
        final int column, final int type, final ResultSet resultSet)
        throws SQLException {
        switch ( type ) {
            case Types.BIT:
                // we do get BIT for 't' 'f' as well as BIT strings e.g. "0110" :
                final String bits = resultSet.getString(column);
                if ( bits == null ) return context.nil;
                if ( bits.length() > 1 ) {
                    return RubyString.newUnicodeString(runtime, bits);
                }
                return booleanToRuby(context, runtime, resultSet, column);
            //case Types.JAVA_OBJECT: case Types.OTHER:
                //return objectToRuby(runtime, resultSet, resultSet.getObject(column));
        }
        return super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    @Override
    protected boolean useByteStrings() { return true; }

    @Override
    protected IRubyObject dateToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {

        if ( rawDateTime != null && rawDateTime.booleanValue() ) {
            final byte[] value = resultSet.getBytes(column);
            if ( value == null ) {
                if ( resultSet.wasNull() ) return context.nil;
                return RubyString.newEmptyString(runtime); // ""
            }
            return RubyString.newString(runtime, new ByteList(value, false));
        }

        final String value = resultSet.getString(column);
        if ( value == null ) return context.nil;

        return DateTimeUtils.parseDate(context, value);
    }

    @Override
    protected IRubyObject timeToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        return timestampToRuby(context, runtime, resultSet, column);
    }

    @Override
    protected IRubyObject timestampToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {

        if ( rawDateTime != null && rawDateTime.booleanValue() ) {
            final byte[] value = resultSet.getBytes(column);
            if ( value == null ) {
                if ( resultSet.wasNull() ) return context.nil;
                return RubyString.newEmptyString(runtime); // ""
            }
            return RubyString.newString(runtime, new ByteList(value, false));
        }

        // NOTE: using Timestamp we would loose information such as BC :
        // Timestamp: '0001-12-31 22:59:59.0' String: '0001-12-31 22:59:59 BC'

        final String value = resultSet.getString(column);
        if ( value == null ) return context.nil;

        // string_to_time
        final int len = value.length();
        if ( (len == 8 || len == 9) && value.charAt(len - 1) == 'y' ) {
            if ( value.charAt(0) == '-' ) { // 'infinity' / '-infinity'
                return RubyFloat.newFloat(context.runtime, -RubyFloat.INFINITY);
            }
            return RubyFloat.newFloat(context.runtime, RubyFloat.INFINITY);
        }
        return DateTimeUtils.parseDateTime(context, value);
    }

    @Override
    protected IRubyObject arrayToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        if ( rawArrayType == Boolean.TRUE ) { // pre AR 4.0 compatibility
            return stringToRuby(context, runtime, resultSet, column);
        }
        // NOTE: avoid `finally { array.free(); }` on PostgreSQL due :
        // java.sql.SQLFeatureNotSupportedException:
        // Method org.postgresql.jdbc4.Jdbc4Array.free() is not yet implemented.
        final Array value = resultSet.getArray(column);

        if ( value == null /* || resultSet.wasNull() */ ) return context.nil;

        final RubyArray array = RubyArray.newArray(runtime);

        final ResultSet arrayResult = value.getResultSet(); // 1: index, 2: value
        final int baseType = value.getBaseType();
        while ( arrayResult.next() ) {
            array.append( jdbcToRuby(context, runtime, 2, baseType, arrayResult) );
        }
        return array;
    }

    @Override
    protected final IRubyObject objectToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        return driverImplementation().objectToRuby(context, resultSet, column);
    }

    @Override
    protected TableName extractTableName(
        final Connection connection, String catalog, String schema,
        final String tableName) throws IllegalArgumentException, SQLException {
        // The postgres JDBC driver will default to searching every schema if no
        // schema search path is given.  Default to the 'public' schema instead:
        if ( schema == null ) schema = "public";
        return super.extractTableName(connection, catalog, schema, tableName);
    }

    static Boolean rawArrayType;
    static {
        final String arrayRaw = System.getProperty("arjdbc.postgresql.array.raw");
        if ( arrayRaw != null ) rawArrayType = Boolean.parseBoolean(arrayRaw);
    }

    @JRubyMethod(name = "raw_array_type?", meta = true)
    public static IRubyObject useRawArrayType(final ThreadContext context, final IRubyObject self) {
        if ( rawArrayType == null ) return context.nil;
        return context.runtime.newBoolean(rawArrayType);
    }

    @JRubyMethod(name = "raw_array_type=", meta = true)
    public static IRubyObject setRawArrayType(final IRubyObject self, final IRubyObject value) {
        if ( value instanceof RubyBoolean ) {
            rawArrayType = ((RubyBoolean) value).isTrue() ? Boolean.TRUE : Boolean.FALSE;
        }
        else {
            rawArrayType = value.isNil() ? null : Boolean.TRUE;
        }
        return value;
    }

    static Boolean rawHstoreType;
    static {
        final String hstoreRaw = System.getProperty("arjdbc.postgresql.hstore.raw");
        if ( hstoreRaw != null ) rawHstoreType = Boolean.parseBoolean(hstoreRaw);
    }

    @JRubyMethod(name = "raw_hstore_type?", meta = true)
    public static IRubyObject useRawHstoreType(final ThreadContext context, final IRubyObject self) {
        if ( rawHstoreType == null ) return context.nil;
        return context.runtime.newBoolean(rawHstoreType);
    }

    @JRubyMethod(name = "raw_hstore_type=", meta = true)
    public static IRubyObject setRawHstoreType(final IRubyObject self, final IRubyObject value) {
        if ( value instanceof RubyBoolean ) {
            rawHstoreType = ((RubyBoolean) value).isTrue() ? Boolean.TRUE : Boolean.FALSE;
        }
        else {
            rawHstoreType = value.isNil() ? null : Boolean.TRUE;
        }
        return value;
    }

    // whether to use "raw" interval values off by default - due native adapter compatibilty :
    // RAW values :
    // - 2 years 0 mons 0 days 0 hours 3 mins 0.00 secs
    // - -1 years 0 mons -2 days 0 hours 0 mins 0.00 secs
    // Rails style :
    // - 2 years 00:03:00
    // - -1 years -2 days
    static boolean rawIntervalType = Boolean.getBoolean("arjdbc.postgresql.iterval.raw");

    @JRubyMethod(name = "raw_interval_type?", meta = true)
    public static IRubyObject useRawIntervalType(final ThreadContext context, final IRubyObject self) {
        return context.runtime.newBoolean(rawIntervalType);
    }

    @JRubyMethod(name = "raw_interval_type=", meta = true)
    public static IRubyObject setRawIntervalType(final IRubyObject self, final IRubyObject value) {
        if ( value instanceof RubyBoolean ) {
            rawIntervalType = ((RubyBoolean) value).isTrue();
        }
        else {
            rawIntervalType = ! value.isNil();
        }
        return value;
    }

}
