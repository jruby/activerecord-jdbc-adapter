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
package arjdbc.postgresql;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.math.BigDecimal;
import java.sql.Array;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.Map;
import java.util.UUID;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyFixnum;
import org.jruby.RubyFloat;
import org.jruby.RubyHash;
import org.jruby.RubyIO;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;
import org.jcodings.specific.UTF8Encoding;

import org.postgresql.PGConnection;
import org.postgresql.PGStatement;
import org.postgresql.core.BaseConnection;
import org.postgresql.jdbc4.Jdbc4Array;
import org.postgresql.util.PGInterval;
import org.postgresql.util.PGobject;

/**
 *
 * @author enebo
 */
public class PostgreSQLRubyJdbcConnection extends arjdbc.jdbc.RubyJdbcConnection {
    private static final long serialVersionUID = 7235537759545717760L;

    public PostgreSQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createPostgreSQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("PostgreSQLJdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(PostgreSQLRubyJdbcConnection.class);
        getConnectionAdapters(runtime).setConstant("PostgresJdbcConnection", clazz); // backwards-compat
        return clazz;
    }

    protected static ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new PostgreSQLRubyJdbcConnection(runtime, klass);
        }
    };

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
    protected String caseConvertIdentifierForRails(final Connection connection, final String value)
        throws SQLException {
        return value;
    }

    @Override
    protected String caseConvertIdentifierForJdbc(final Connection connection, final String value)
        throws SQLException {
        return value;
    }

    @Override
    protected Connection newConnection() throws SQLException {
        final Connection connection = getConnectionFactory().newConnection();
        final PGConnection pgConnection;
        if ( connection instanceof PGConnection ) {
            pgConnection = (PGConnection) connection;
        }
        else {
            pgConnection = connection.unwrap(PGConnection.class);
        }
        pgConnection.addDataType("daterange", DateRangeType.class);
        pgConnection.addDataType("tsrange",   TsRangeType.class);
        pgConnection.addDataType("tstzrange", TstzRangeType.class);
        pgConnection.addDataType("int4range", Int4RangeType.class);
        pgConnection.addDataType("int8range", Int8RangeType.class);
        pgConnection.addDataType("numrange",  NumRangeType.class);
        return connection;
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

        if ( value instanceof RubyFloat ) {
            final double _value = ( (RubyFloat) value ).getValue();
            if ( Double.isInfinite(_value) ) {
                final Timestamp timestamp;
                if ( _value < 0 ) {
                    timestamp = new Timestamp(PGStatement.DATE_NEGATIVE_INFINITY);
                }
                else {
                    timestamp = new Timestamp(PGStatement.DATE_POSITIVE_INFINITY);
                }
                statement.setTimestamp( index, timestamp );
                return;
            }
        }

        super.setTimestampParameter(context, connection, statement, index, value, column, type);
    }

    private static final ByteList INTERVAL =
        new ByteList( new byte[] { 'i','n','t','e','r','v','a','l' }, false );

    private static final ByteList ARRAY_END = new ByteList( new byte[] { '[',']' }, false );

    @Override
    protected void setStringParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {
        final RubyString sqlType;
        if ( column != null && ! column.isNil() ) {
            sqlType = (RubyString) column.callMethod(context, "sql_type");
        }
        else {
            sqlType = null;
        }

        if ( value.isNil() ) {
            if ( rawArrayType == Boolean.TRUE ) { // array's type is :string
                if ( sqlType != null && sqlType.getByteList().endsWith( ARRAY_END ) ) {
                    statement.setNull(index, Types.ARRAY); return;
                }
                statement.setNull(index, type); return;
            }
            statement.setNull(index, Types.VARCHAR);
        }
        else {
            final String valueStr = value.asString().toString();
            if ( sqlType != null ) {
                if ( rawArrayType == Boolean.TRUE && sqlType.getByteList().endsWith( ARRAY_END ) ) {
                    final int oid = oid(context, column);
                    final Array valueArr = new Jdbc4Array(connection.unwrap(BaseConnection.class), oid, valueStr);
                    statement.setArray(index, valueArr); return;
                }
                if ( sqlType.getByteList().startsWith( INTERVAL ) ) {
                    statement.setObject( index, new PGInterval( valueStr ) ); return;
                }
            }
            statement.setString( index, valueStr );
        }
    }

    private static int oid(final ThreadContext context, final IRubyObject column) {
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

        final String columnType = column.callMethod(context, "type").asJavaString();

        if ( columnType == (Object) "uuid" ) {
            setUUIDParameter(statement, index, value);
            return;
        }

        if ( columnType == (Object) "json" ) {
            setJsonParameter(context, statement, index, value, column);
            return;
        }

        if ( columnType == (Object) "tsvector" ) {
            setTsVectorParameter(statement, index, value);
            return;
        }

        if ( columnType == (Object) "cidr" || columnType == (Object) "inet"
                || columnType == (Object) "macaddr" ) {
            setAddressParameter(context, statement, index, value, column, columnType);
            return;
        }

        if ( columnType != null && columnType.endsWith("range") ) {
            setRangeParameter(context, statement, index, value, column, columnType);
            return;
        }

        super.setObjectParameter(context, connection, statement, index, value, column, type);
    }

    private void setUUIDParameter(
        final PreparedStatement statement, final int index,
        Object value) throws SQLException {

        if ( value instanceof IRubyObject ) {
            final IRubyObject rubyValue = (IRubyObject) value;
            if ( rubyValue.isNil() ) {
                statement.setNull(index, Types.OTHER); return;
            }
        }
        else if ( value == null ) {
            statement.setNull(index, Types.OTHER); return;
        }

        final Object uuid = UUID.fromString( value.toString() );
        statement.setObject(index, uuid);
    }

    private void setJsonParameter(final ThreadContext context,
        final PreparedStatement statement, final int index,
        Object value, final IRubyObject column) throws SQLException {

        if ( value instanceof IRubyObject ) {
            final IRubyObject rubyValue = (IRubyObject) value;
            if ( rubyValue.isNil() ) {
                statement.setNull(index, Types.OTHER); return;
            }
            value = column.getMetaClass().callMethod(context, "json_to_string", rubyValue);
        }
        else if ( value == null ) {
            statement.setNull(index, Types.OTHER); return;
        }

        final PGobject pgJson = new PGobject();
        pgJson.setType("json");
        pgJson.setValue(value.toString());
        statement.setObject(index, pgJson);
    }

    private void setTsVectorParameter(
        final PreparedStatement statement, final int index,
        Object value) throws SQLException {

        if ( value instanceof IRubyObject ) {
            final IRubyObject rubyValue = (IRubyObject) value;
            if ( rubyValue.isNil() ) {
                statement.setNull(index, Types.OTHER); return;
            }
        }
        else if ( value == null ) {
            statement.setNull(index, Types.OTHER); return;
        }

        final PGobject pgTsVector = new PGobject();
        pgTsVector.setType("tsvector");
        pgTsVector.setValue(value.toString());
        statement.setObject(index, pgTsVector);
    }

    private void setAddressParameter(final ThreadContext context,
        final PreparedStatement statement, final int index,
        Object value, final IRubyObject column,
        final String columnType) throws SQLException {

        if ( value instanceof IRubyObject ) {
            final IRubyObject rubyValue = (IRubyObject) value;
            if ( rubyValue.isNil() ) {
                statement.setNull(index, Types.OTHER); return;
            }
            value = column.getMetaClass().callMethod(context, "cidr_to_string", rubyValue);
        }
        else if ( value == null ) {
            statement.setNull(index, Types.OTHER); return;
        }

        final PGobject pgAddress = new PGobject();
        pgAddress.setType(columnType);
        pgAddress.setValue(value.toString());
        statement.setObject(index, pgAddress);
    }

    private void setRangeParameter(final ThreadContext context,
        final PreparedStatement statement, final int index,
        final Object value, final IRubyObject column,
        final String columnType) throws SQLException {

        final String rangeValue;

        if ( value instanceof IRubyObject ) {
            final IRubyObject rubyValue = (IRubyObject) value;
            if ( rubyValue.isNil() ) {
                statement.setNull(index, Types.OTHER); return;
            }
            rangeValue = column.getMetaClass().callMethod(context, "range_to_string", rubyValue).toString();
        }
        else {
            if ( value == null ) {
                statement.setNull(index, Types.OTHER); return;
            }
            rangeValue = value.toString();
        }

        final Object pgRange;
        if ( columnType == (Object) "daterange" ) {
            pgRange = new DateRangeType(rangeValue);
        }
        else if ( columnType == (Object) "tsrange" ) {
            pgRange = new TsRangeType(rangeValue);
        }
        else if ( columnType == (Object) "tstzrange" ) {
            pgRange = new TstzRangeType(rangeValue);
        }
        else if ( columnType == (Object) "int4range" ) {
            pgRange = new Int4RangeType(rangeValue);
        }
        else if ( columnType == (Object) "int8range" ) {
            pgRange = new Int8RangeType(rangeValue);
        }
        else { // if ( columnType == (Object) "numrange" )
            pgRange = new NumRangeType(rangeValue);
        }
        statement.setObject(index, pgRange);
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

    private static final int HSTORE_TYPE = 100000 + 1111;

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
                if ( bits == null ) return runtime.getNil();
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
    protected IRubyObject timestampToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        // NOTE: using Timestamp we loose information such as BC :
        // Timestamp: '0001-12-31 22:59:59.0' String: '0001-12-31 22:59:59 BC'
        final byte[] value = resultSet.getBytes(column);
        if ( value == null ) {
            if ( resultSet.wasNull() ) return runtime.getNil();
            return runtime.newString(); // ""
        }

        final RubyString strValue = RubyString.newString(runtime, new ByteList(value, false));
        if ( rawDateTime != null && rawDateTime.booleanValue() ) return strValue;

        final IRubyObject adapter = callMethod(context, "adapter"); // self.adapter
        if ( adapter.isNil() ) return strValue; // NOTE: we warn on init_connection
        return adapter.callMethod(context, "_string_to_timestamp", strValue);
    }

    @Override // optimized String -> byte[]
    protected IRubyObject stringToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final byte[] value = resultSet.getBytes(column);
        if ( value == null && resultSet.wasNull() ) return runtime.getNil();
        return newUTF8String(runtime, value);
    }

    private static RubyString newUTF8String(final Ruby runtime, final byte[] bytes) {
        final ByteList byteList = new ByteList(bytes, false);
        return RubyString.newString(runtime, byteList, UTF8Encoding.INSTANCE);
    }

    @Override // optimized CLOBs
    protected IRubyObject readerToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        return stringToRuby(context, runtime, resultSet, column);
    }

    @Override // optimized String -> byte[]
    protected IRubyObject decimalToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        if ( bigDecimalExt ) { // "optimized" path (JRuby 1.7+)
            final BigDecimal value = resultSet.getBigDecimal(column);
            if ( value == null && resultSet.wasNull() ) return runtime.getNil();
            return new org.jruby.ext.bigdecimal.RubyBigDecimal(runtime, value);
        }

        final byte[] value = resultSet.getBytes(column);
        if ( value == null && resultSet.wasNull() ) return runtime.getNil();
        final RubyString valueStr = runtime.newString(new ByteList(value, false));
        return runtime.getKernel().callMethod("BigDecimal", valueStr);
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

        if ( value == null && resultSet.wasNull() ) return runtime.getNil();

        final RubyArray array = runtime.newArray();

        final ResultSet arrayResult = value.getResultSet(); // 1: index, 2: value
        final int baseType = value.getBaseType();
        while ( arrayResult.next() ) {
            array.append( jdbcToRuby(context, runtime, 2, baseType, arrayResult) );
        }
        return array;
    }

    @Override
    protected IRubyObject objectToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {

        final Object object = resultSet.getObject(column);

        if ( object == null && resultSet.wasNull() ) return runtime.getNil();

        final Class<?> objectClass = object.getClass();
        if ( objectClass == UUID.class ) {
            return runtime.newString( object.toString() );
        }

        if ( objectClass == PGInterval.class ) {
            return runtime.newString( formatInterval(object) );
        }

        if ( object instanceof PGobject ) {
            // PG 9.2 JSON type will be returned here as well
            return runtime.newString( object.toString() );
        }

        if ( object instanceof Map ) { // hstore
            if ( rawHstoreType == Boolean.TRUE ) {
                return runtime.newString( resultSet.getString(column) );
            }
            // by default we avoid double parsing by driver and than column :
            final RubyHash rubyObject = RubyHash.newHash(runtime);
            rubyObject.putAll((Map) object); // converts keys/values to ruby
            return rubyObject;
        }

        return JavaUtil.convertJavaToRuby(runtime, object);
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

    // NOTE: do not use PG classes in the API so that loading is delayed !
    private String formatInterval(final Object object) {
        final PGInterval interval = (PGInterval) object;
        if ( rawIntervalType ) return interval.getValue();

        final StringBuilder str = new StringBuilder(32);

        final int years = interval.getYears();
        if ( years != 0 ) str.append(years).append(" years ");
        final int months = interval.getMonths();
        if ( months != 0 ) str.append(months).append(" months ");
        final int days = interval.getDays();
        if ( days != 0 ) str.append(days).append(" days ");
        final int hours = interval.getHours();
        final int mins = interval.getMinutes();
        final int secs = (int) interval.getSeconds();
        if ( hours != 0 || mins != 0 || secs != 0 ) { // xx:yy:zz if not all 00
            if ( hours < 10 ) str.append('0');
            str.append(hours).append(':');
            if ( mins < 10 ) str.append('0');
            str.append(mins).append(':');
            if ( secs < 10 ) str.append('0');
            str.append(secs);
        }
        else {
            if ( str.length() > 1 ) str.deleteCharAt( str.length() - 1 ); // " " at the end
        }

        return str.toString();
    }

    protected static Boolean rawArrayType;
    static {
        final String arrayRaw = System.getProperty("arjdbc.postgresql.array.raw");
        if ( arrayRaw != null ) rawArrayType = Boolean.parseBoolean(arrayRaw);
    }

    @JRubyMethod(name = "raw_array_type?", meta = true)
    public static IRubyObject useRawArrayType(final ThreadContext context, final IRubyObject self) {
        if ( rawArrayType == null ) return context.runtime.getNil();
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

    protected static Boolean rawHstoreType;
    static {
        final String hstoreRaw = System.getProperty("arjdbc.postgresql.hstore.raw");
        if ( hstoreRaw != null ) rawHstoreType = Boolean.parseBoolean(hstoreRaw);
    }

    @JRubyMethod(name = "raw_hstore_type?", meta = true)
    public static IRubyObject useRawHstoreType(final ThreadContext context, final IRubyObject self) {
        if ( rawHstoreType == null ) return context.runtime.getNil();
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
    protected static boolean rawIntervalType = Boolean.getBoolean("arjdbc.postgresql.iterval.raw");

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

    // NOTE: without these custom registered Postgre (driver) types
    // ... we can not set range parameters in prepared statements !

    public static class DateRangeType extends PGobject {

        public DateRangeType() {
            setType("daterange");
        }

        public DateRangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class TsRangeType extends PGobject {

        public TsRangeType() {
            setType("tsrange");
        }

        public TsRangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class TstzRangeType extends PGobject {

        public TstzRangeType() {
            setType("tstzrange");
        }

        public TstzRangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class Int4RangeType extends PGobject {

        public Int4RangeType() {
            setType("int4range");
        }

        public Int4RangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class Int8RangeType extends PGobject {

        public Int8RangeType() {
            setType("int8range");
        }

        public Int8RangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class NumRangeType extends PGobject {

        public NumRangeType() {
            setType("numrange");
        }

        public NumRangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

}
