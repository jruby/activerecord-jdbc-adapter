/*
 **** BEGIN LICENSE BLOCK *****
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
import java.sql.Array;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.List;
import java.util.UUID;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyFloat;
import org.jruby.RubyIO;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

import org.postgresql.PGConnection;
import org.postgresql.PGStatement;
import org.postgresql.util.PGInterval;
import org.postgresql.util.PGobject;

/**
 *
 * @author enebo
 */
public class PostgreSQLRubyJdbcConnection extends arjdbc.jdbc.RubyJdbcConnection {

    protected PostgreSQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createPostgreSQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("PostgreSQLJdbcConnection", jdbcConnection, POSTGRESQL_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(PostgreSQLRubyJdbcConnection.class);
        getConnectionAdapters(runtime).setConstant("PostgresJdbcConnection", clazz); // backwards-compat
        return clazz;
    }

    private static ObjectAllocator POSTGRESQL_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new PostgreSQLRubyJdbcConnection(runtime, klass);
        }
    };

    // enables testing if the bug is fixed (please run our test-suite)
    // using `rake test_postgresql JRUBY_OPTS="-J-Darjdbc.postgresql.generated.keys=true"`
    protected static final boolean generatedKeys = Boolean.getBoolean("arjdbc.postgresql.generated.keys");

    @Override
    protected IRubyObject mapGeneratedKeys(
        final Ruby runtime, final Connection connection,
        final Statement statement, final Boolean singleResult)
        throws SQLException {
        if ( generatedKeys ) {
            super.mapGeneratedKeys(runtime, connection, statement, singleResult);
        }
        // NOTE: PostgreSQL driver supports generated keys but does not work
        // correctly for all cases e.g. for tables whene no keys are generated
        // during an INSERT getGeneratedKeys return all inserted rows instead
        // of an empty result set ... thus disabled until issue is resolved !
        return null; // not supported
    }

    @Override
    protected String caseConvertIdentifierForJdbc(final DatabaseMetaData metaData, final String value)
        throws SQLException {
        if ( value != null ) {
            if ( metaData.storesUpperCaseIdentifiers() ) {
                return value.toUpperCase();
            }
            // for PostgreSQL we do not care about storesLowerCaseIdentifiers()
        }
        return value;
    }

    @Override
    protected void setStatementParameters(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final List<?> binds) throws SQLException {

        ((PGConnection) connection).addDataType("daterange", DateRangeType.class);
        ((PGConnection) connection).addDataType("tsrange",   TsRangeType.class);
        ((PGConnection) connection).addDataType("tstzrange", TstzRangeType.class);
        ((PGConnection) connection).addDataType("int4range", Int4RangeType.class);
        ((PGConnection) connection).addDataType("int8range", Int8RangeType.class);
        ((PGConnection) connection).addDataType("numrange",  NumRangeType.class);

        super.setStatementParameters(context, connection, statement, binds);
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

    @Override
    protected void setStringParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {
        if ( value.isNil() ) statement.setNull(index, Types.VARCHAR);
        else {
            if ( column != null && ! column.isNil() ) {
                final RubyString sqlType = column.callMethod(context, "sql_type").asString();

                if ( sqlType.getByteList().startsWith( INTERVAL ) ) {
                    statement.setObject( index, new PGInterval( value.asString().toString() ) );
                    return;
                }
            }
            statement.setString( index, value.asString().toString() );
        }
    }

    @Override
    protected void setObjectParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, Object value,
        final IRubyObject column, final int type) throws SQLException {

        final String columnType = column.callMethod(context, "type").asJavaString();

        if ( columnType != null && columnType.endsWith("range") ) {
            setRangeParameter(context, statement, index, value, column, columnType);
            return;
        }

        if ( columnType == (Object) "tsvector" ) {
            setTsVectorParameter(statement, index, value, columnType);
            return;
        }

        if ( columnType == (Object) "cidr" || columnType == (Object) "inet"
                || columnType == (Object) "macaddr" ) {
            setAddressParameter(context, statement, index, value, column, columnType);
            return;
        }

        super.setObjectParameter(context, connection, statement, index, value, column, type);
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

    private void setTsVectorParameter(
        final PreparedStatement statement, final int index,
        Object value, final String columnType) throws SQLException {

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
        pgTsVector.setType(columnType); // "tsvector"
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

    @Override
    protected String resolveArrayBaseTypeName(final ThreadContext context,
        final Object value, final IRubyObject column, final int type) {
        String sqlType = column.callMethod(context, "sql_type").toString();
        if ( sqlType.startsWith("character varying") ) return "text";
        final int index = sqlType.indexOf('('); // e.g. "character varying(255)"
        if ( index > 0 ) sqlType = sqlType.substring(0, index);
        return sqlType;
    }

    @Override
    protected int jdbcTypeFor(final ThreadContext context, final Ruby runtime,
        final IRubyObject column, final Object value) throws SQLException {
        // NOTE: likely wrong but native adapters handles this thus we should
        // too - used from #table_exists? `binds << [ nil, schema ] if schema`
        if ( column == null || column.isNil() ) return Types.VARCHAR; // assume type == :string
        return super.jdbcTypeFor(context, runtime, column, value);
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
        final String value = resultSet.getString(column);
        if ( value == null ) {
            if ( resultSet.wasNull() ) return runtime.getNil();
            return runtime.newString(); // ""
        }

        final RubyString strValue = timestampToRubyString(runtime, value.toString());
        if ( rawDateTime != null && rawDateTime.booleanValue() ) return strValue;

        final IRubyObject adapter = callMethod(context, "adapter"); // self.adapter
        if ( adapter.isNil() ) return strValue; // NOTE: we warn on init_connection
        return adapter.callMethod(context, "_string_to_timestamp", strValue);
    }

    @Override
    protected IRubyObject arrayToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
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

    // whether to use "raw" interval values off by default - due native adapter compatibilty :
    // RAW values :
    // - 2 years 0 mons 0 days 0 hours 3 mins 0.00 secs
    // - -1 years 0 mons -2 days 0 hours 0 mins 0.00 secs
    // Rails style :
    // - 2 years 00:03:00
    // - -1 years -2 days
    protected static boolean rawIntervalType = Boolean.getBoolean("arjdbc.postgresql.iterval.raw");

    @JRubyMethod(name = "raw_interval_type?")
    public static IRubyObject useRawIntervalType(final ThreadContext context, final IRubyObject self) {
        return context.getRuntime().newBoolean(rawIntervalType);
    }

    @JRubyMethod(name = "raw_interval_type=")
    public static IRubyObject setRawIntervalType(final IRubyObject self, final IRubyObject value) {
        if ( value instanceof RubyBoolean ) {
            rawIntervalType = ((RubyBoolean) value).isTrue();
        }
        else {
            rawIntervalType = value.isNil();
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
