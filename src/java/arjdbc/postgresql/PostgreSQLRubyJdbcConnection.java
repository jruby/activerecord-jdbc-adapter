/*
 ***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2015 Karol Bucek <self@kares.org>
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

import arjdbc.jdbc.Callable;
import arjdbc.jdbc.DriverWrapper;
import arjdbc.util.DateTimeUtils;
import arjdbc.util.PG;
import arjdbc.util.StringHelper;

import java.io.ByteArrayInputStream;
import java.lang.StringBuilder;
import java.lang.reflect.InvocationTargetException;
import java.math.BigDecimal;
import java.sql.*;
import java.sql.Date;
import java.util.*;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

import org.joda.time.DateTime;
import org.jruby.*;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.ext.bigdecimal.RubyBigDecimal;
import org.jruby.ext.date.RubyDate;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

import org.jruby.util.TypeConverter;
import org.postgresql.PGConnection;
import org.postgresql.PGStatement;
import org.postgresql.geometric.PGbox;
import org.postgresql.geometric.PGcircle;
import org.postgresql.geometric.PGline;
import org.postgresql.geometric.PGlseg;
import org.postgresql.geometric.PGpath;
import org.postgresql.geometric.PGpoint;
import org.postgresql.geometric.PGpolygon;
import org.postgresql.util.PGInterval;
import org.postgresql.util.PGobject;

/**
 *
 * @author enebo
 */
public class PostgreSQLRubyJdbcConnection extends arjdbc.jdbc.RubyJdbcConnection {
    private static final long serialVersionUID = 7235537759545717760L;
    private static final int HSTORE_TYPE = 100000 + 1111;
    private static final Pattern doubleValuePattern = Pattern.compile("(-?\\d+(?:\\.\\d+)?)");
    private static final Pattern uuidPattern = Pattern.compile("\\{?\\p{XDigit}{4}(?:-?(\\p{XDigit}{4})){7}\\}?"); // Fuzzy match postgres's allowed formats

    private static final Map<String, Integer> POSTGRES_JDBC_TYPE_FOR = new HashMap<>(32, 1);
    static {
        POSTGRES_JDBC_TYPE_FOR.put("bit", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("bit_varying", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("box", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("circle", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("citext", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("daterange", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("hstore", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("int4range", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("int8range", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("interval", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("json", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("jsonb", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("line", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("lseg", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("ltree", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("money", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("numrange", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("path", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("point", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("polygon", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("tsrange", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("tstzrange", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("tsvector", Types.OTHER);
        POSTGRES_JDBC_TYPE_FOR.put("uuid", Types.OTHER);
    }

    // Used to wipe trailing 0's from points (3.0, 5.6) -> (3, 5.6)
    private static final Pattern pointCleanerPattern = Pattern.compile("\\.0\\b");
    private static final TimeZone TZ_DEFAULT = TimeZone.getDefault();

    private RubyClass resultClass;
    private RubyHash typeMap = null;

    public PostgreSQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);

        resultClass = getMetaClass().getClass("Result");
    }

    public static RubyClass createPostgreSQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("PostgreSQLJdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(PostgreSQLRubyJdbcConnection.class);
        getConnectionAdapters(runtime).setConstant("PostgresJdbcConnection", clazz); // backwards-compat
        return clazz;
    }

    public static RubyClass load(final Ruby runtime) {
        RubyClass jdbcConnection = getJdbcConnection(runtime);
        RubyClass postgreSQLConnection = createPostgreSQLJdbcConnectionClass(runtime, jdbcConnection);
        PostgreSQLResult.createPostgreSQLResultClass(runtime, postgreSQLConnection);
        return postgreSQLConnection;
    }

    protected static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new PostgreSQLRubyJdbcConnection(runtime, klass);
        }
    };

    @Override
    protected String buildURL(final ThreadContext context, final IRubyObject url) {
        // (deprecated AR-JDBC specific url) options: disabled with adapter: postgresql
        // since it collides with AR as it likes to use the key for its own purposes :
        // e.g. config[:options] = "-c geqo=off"
        return DriverWrapper.buildURL(url, Collections.EMPTY_MAP);
    }

    @Override
    protected DriverWrapper newDriverWrapper(final ThreadContext context, final String driver) {
        DriverWrapper driverWrapper = super.newDriverWrapper(context, driver);

        final java.sql.Driver jdbcDriver = driverWrapper.getDriverInstance();
        if ( jdbcDriver.getClass().getName().startsWith("org.postgresql.") ) {
            try { // public static String getVersion()
                final String version = (String) // "PostgreSQL 9.2 JDBC4 (build 1002)"
                    jdbcDriver.getClass().getMethod("getVersion").invoke(null);
                if ( version != null && version.contains("JDBC3")) {
                    // config[:connection_alive_sql] ||= 'SELECT 1'
                    setConfigValueIfNotSet(context, "connection_alive_sql", context.runtime.newString("SELECT 1"));
                }
            }
            catch (NoSuchMethodException | SecurityException | InvocationTargetException | IllegalAccessException ignored) { }
        }

        return driverWrapper;
    }

    @Override
    protected final IRubyObject beginTransaction(final ThreadContext context, final Connection connection,
        final IRubyObject isolation) throws SQLException {
        // NOTE: only reversed order - just to ~ match how Rails does it :
        /* if ( connection.getAutoCommit() ) */ connection.setAutoCommit(false);
        if ( isolation != null ) setTransactionIsolation(context, connection, isolation);
        return context.nil;
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
    protected String internedTypeFor(final ThreadContext context, final IRubyObject attribute) throws SQLException {
        RubyClass arrayClass = oidArray(context);
        RubyBasicObject attributeType = (RubyBasicObject) attributeType(context, attribute);
        // The type or its delegate is an OID::Array
        if (arrayClass.isInstance(attributeType) ||
                (attributeType.hasInstanceVariable("@delegate_dc_obj") &&
                        arrayClass.isInstance(attributeType.getInstanceVariable("@delegate_dc_obj")))) {
            return "array";
        }

        return super.internedTypeFor(context, attribute);
    }

    @JRubyMethod(name = "database_product")
    public IRubyObject database_product(final ThreadContext context) {
        return withConnection(context, (Callable<IRubyObject>) connection -> {
            final DatabaseMetaData metaData = connection.getMetaData();
            return RubyString.newString(context.runtime, metaData.getDatabaseProductName() + ' ' + metaData.getDatabaseProductVersion());
        });
    }

    private transient RubyClass oidArray; // PostgreSQL::OID::Array

    private RubyClass oidArray(final ThreadContext context) {
        if (oidArray != null) return oidArray;
        final RubyModule PostgreSQL = (RubyModule) getConnectionAdapters(context.runtime).getConstant("PostgreSQL");
        return oidArray = ((RubyModule) PostgreSQL.getConstantAt("OID")).getClass("Array");
    }


    @Override
    protected Connection newConnection() throws RaiseException, SQLException {
        final Connection connection;
        try {
            connection = super.newConnection();
        }
        catch (SQLException ex) {
            if ("3D000".equals(ex.getSQLState())) { // invalid_catalog_name
                //  org.postgresql.util.PSQLException: FATAL: database "xxx" does not exist
                throw newNoDatabaseError(ex);
            }
            throw ex;
        }
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

    @Override
    protected PostgreSQLResult mapExecuteResult(final ThreadContext context, final Connection connection,
                                                final ResultSet resultSet) throws SQLException {
        return PostgreSQLResult.newResult(context, resultClass, this, resultSet);
    }

    /**
     * Maps a query result set into a <code>ActiveRecord</code> result.
     * @param context
     * @param connection
     * @param resultSet
     * @return <code>ActiveRecord::Result</code>
     * @throws SQLException
     */
    @Override
    protected IRubyObject mapQueryResult(final ThreadContext context, final Connection connection,
                                         final ResultSet resultSet) throws SQLException {
        return mapExecuteResult(context, connection, resultSet).toARResult(context);
    }

    @Override
    protected void setArrayParameter(final ThreadContext context,
                                     final Connection connection, final PreparedStatement statement,
                                     final int index, final IRubyObject value,
                                     final IRubyObject attribute, final int type) throws SQLException {

        final String typeName = resolveArrayBaseTypeName(context, attribute);
        final RubyArray valueForDB = (RubyArray) value.callMethod(context, "values");

        Object[] values;
        switch (typeName) {
        case "datetime":
        case "timestamp": {
            values = PgDateTimeUtils.timestampStringArray(context, valueForDB);
            break;
        }
        default:
            values = valueForDB.toArray();
            break;
        }

        statement.setArray(index, connection.createArrayOf(typeName, values));
    }

    protected void setDecimalParameter(final ThreadContext context,
                                       final Connection connection, final PreparedStatement statement,
                                       final int index, final IRubyObject value,
                                       final IRubyObject attribute, final int type) throws SQLException {
        if (value instanceof RubyBigDecimal) {
            RubyBigDecimal bigDecimal = (RubyBigDecimal) value;

            // too bad RubyBigDecimal.isNaN() isn't public
            if (bigDecimal.nan_p(context) == context.tru) {
                statement.setDouble(index, Double.NaN);
            } else {
                statement.setBigDecimal(index, bigDecimal.getValue());
            }
        } else {
            super.setDecimalParameter(context, connection, statement, index, value, attribute, type);
        }
    }

    @Override
    protected void setBlobParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if ( value instanceof RubyIO ) { // IO/File
            statement.setBinaryStream(index, ((RubyIO) value).getInStream());
        }
        else { // should be a RubyString
            final ByteList bytes = value.asString().getByteList();
            statement.setBinaryStream(index,
                    new ByteArrayInputStream(bytes.unsafeBytes(), bytes.getBegin(), bytes.getRealSize()),
                    bytes.getRealSize() // length
            );
        }
    }

    @Override // to handle infinity timestamp values
    protected void setTimestampParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {
        // PGJDBC uses strings internally anyway, so using Timestamp doesn't do any good
        String tsString = PgDateTimeUtils.timestampValueToString(context, value, null, true);
        statement.setObject(index, tsString, Types.OTHER);
    }

    private static void setTimestampInfinity(final PreparedStatement statement,
                                             final int index, final double value) throws SQLException {
        final Timestamp timestamp;
        if ( value < 0 ) {
            timestamp = new Timestamp(PGStatement.DATE_NEGATIVE_INFINITY);
        }
        else {
            timestamp = new Timestamp(PGStatement.DATE_POSITIVE_INFINITY);
        }

        statement.setTimestamp( index, timestamp );
    }

    @Override
    protected void setTimeParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {
        // to handle more fractional second precision than (default) 59.123 only
        String timeStr = DateTimeUtils.timeString(context, value, getDefaultTimeZone(context), true);
        statement.setObject(index, timeStr, Types.OTHER);
    }

    @Override
    protected void setDateParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if ( value instanceof RubyFloat ) {
            final double doubleValue = ( (RubyFloat) value ).getValue();
            if ( Double.isInfinite(doubleValue) ) {
                setTimestampInfinity(statement, index, doubleValue);
                return;
            }
        }

        if ( ! "Date".equals(value.getMetaClass().getName()) && value.respondsTo("to_date") ) {
            value = value.callMethod(context, "to_date");
        }

        if (value instanceof RubyDate) {
            RubyDate rubyDate = (RubyDate) value;
            DateTime dt = rubyDate.getDateTime();
            // pgjdbc needs adjustment for default JVM timezone
            statement.setDate(index, new Date(dt.getMillis() - TZ_DEFAULT.getOffset(dt.getMillis())));
            return;
        }

        // NOTE: assuming Date#to_s does right ...
        statement.setDate(index, Date.valueOf(value.toString()));
    }

    @Override
    protected void setObjectParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        final String columnType = attributeSQLType(context, attribute).asJavaString();
        Double[] pointValues;

        switch ( columnType ) {
            case "bit":
            case "bit_varying":
                // value should be a ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Bit::Data
                setPGobjectParameter(statement, index, value.toString(), "bit");
                break;

            case "box":
                pointValues = parseDoubles(value);
                statement.setObject(index, new PGbox(pointValues[0], pointValues[1], pointValues[2], pointValues[3]));
                break;

            case "circle":
                pointValues = parseDoubles(value);
                statement.setObject(index, new PGcircle(pointValues[0], pointValues[1], pointValues[2]));
                break;

            case "cidr":
            case "citext":
            case "hstore":
            case "inet":
            case "ltree":
            case "macaddr":
            case "tsvector":
                setPGobjectParameter(statement, index, value, columnType);
                break;

            case "enum":
                statement.setObject(index, value.toString(), Types.OTHER);
                break;

            case "interval":
                statement.setObject(index, new PGInterval(value.toString()));
                break;

            case "json":
            case "jsonb":
                setJsonParameter(context, statement, index, value, columnType);
                break;

            case "line":
                pointValues = parseDoubles(value);
                if ( pointValues.length == 3 ) {
                    statement.setObject(index, new PGline(pointValues[0], pointValues[1], pointValues[2]));
                } else {
                    statement.setObject(index, new PGline(pointValues[0], pointValues[1], pointValues[2], pointValues[3]));
                }
                break;

            case "money":
                if (value instanceof RubyBigDecimal) {
                    statement.setBigDecimal(index, ((RubyBigDecimal) value).getValue());
                } else {
                    setPGobjectParameter(statement, index, value, columnType);
                }
                break;

            case "lseg":
                pointValues = parseDoubles(value);
                statement.setObject(index, new PGlseg(pointValues[0], pointValues[1], pointValues[2], pointValues[3]));
                break;

            case "path":
                // If the value starts with "[" it is open, otherwise postgres treats it as a closed path
                statement.setObject(index, new PGpath((PGpoint[]) convertToPoints(parseDoubles(value)), value.toString().startsWith("[")));
                break;

            case "point":
                pointValues = parseDoubles(value);
                statement.setObject(index, new PGpoint(pointValues[0], pointValues[1]));
                break;

            case "polygon":
                statement.setObject(index, new PGpolygon((PGpoint[]) convertToPoints(parseDoubles(value))));
                break;

            case "uuid":
                setUUIDParameter(statement, index, value);
                break;

            default:
                if (columnType.endsWith("range")) {
                    setRangeParameter(context, statement, index, value, columnType);
                } else {
                    setPGobjectParameter(statement, index, value, columnType);
                }
        }
    }

    protected IRubyObject jdbcToRuby(ThreadContext context, Ruby runtime, int column, int type, ResultSet resultSet) throws SQLException {
        return typeMap != null ?
                convertWithTypeMap(context, runtime, column, type, resultSet) :
                super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    private IRubyObject convertWithTypeMap(ThreadContext context, Ruby runtime, int column, int type, ResultSet resultSet) throws SQLException {
        ResultSetMetaData metaData = resultSet.getMetaData();
        IRubyObject decoder = typeMap.op_aref(context, STRING_CACHE.get(context, metaData.getColumnTypeName(column)));

        if (decoder.isNil()) return super.jdbcToRuby(context, runtime, column, type, resultSet);

        return decoder.callMethod(context, "decode", StringHelper.newDefaultInternalString(runtime, resultSet.getString(column)));
    }

    // The tests won't start if this returns PGpoint[]
    // it fails with a runtime error: "NativeException: java.lang.reflect.InvocationTargetException: [Lorg/postgresql/geometric/PGpoint"
    private Object[] convertToPoints(Double[] values) throws SQLException {
        PGpoint[] points = new PGpoint[values.length / 2];

        for ( int i = 0; i < values.length; i += 2 ) {
            points[i / 2] = new PGpoint(values[i], values[i + 1]);
        }

        return points;
    }

    private static Double[] parseDoubles(IRubyObject value) {
        Matcher matches = doubleValuePattern.matcher(value.toString());
        ArrayList<Double> doubles = new ArrayList<>(4); // Paths and polygons may be larger but this covers points/circles/boxes/line segments

        while ( matches.find() ) {
            doubles.add(Double.parseDouble(matches.group()));
        }

        return doubles.toArray(new Double[doubles.size()]);
    }

    private void setJsonParameter(final ThreadContext context,
        final PreparedStatement statement, final int index,
        final IRubyObject value, final String columnType) throws SQLException {

        final PGobject pgJson = new PGobject();
        pgJson.setType(columnType);
        pgJson.setValue(value.toString());
        statement.setObject(index, pgJson);
    }

    private void setPGobjectParameter(final PreparedStatement statement, final int index,
        final Object value, final String columnType) throws SQLException {

        final PGobject param = new PGobject();
        param.setType(columnType);
        param.setValue(value.toString());
        statement.setObject(index, param);
    }

    private void setRangeParameter(final ThreadContext context,
        final PreparedStatement statement, final int index,
        final IRubyObject value, final String columnType) throws SQLException {

        // As of AR 5.2 this is a Range object, I defer to the adapter for encoding because of the edge cases
        // of dealing with the specific types in the range
        final String rangeValue = adapter(context).callMethod(context, "encode_range", value).toString();
        final Object pgRange;

        switch ( columnType ) {
            case "daterange":
                pgRange = new DateRangeType(rangeValue);
                break;
            case "tsrange":
                pgRange = new TsRangeType(rangeValue);
                break;
            case "tstzrange":
                pgRange = new TstzRangeType(rangeValue);
                break;
            case "int4range":
                pgRange = new Int4RangeType(rangeValue);
                break;
            case "int8range":
                pgRange = new Int8RangeType(rangeValue);
                break;
            default:
                pgRange = new NumRangeType(rangeValue, columnType);
        }

        statement.setObject(index, pgRange);
    }

    @Override
    protected void setStringParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if ( attributeSQLType(context, attribute) == context.nil ) {
            /*
                We have to check for a uuid here because in some cases
                (for example,  when doing "exists?" checks, or with legacy binds)
                ActiveRecord doesn't send us the actual type of the attribute
                and Postgres won't compare a uuid column with a string
            */
            final String uuid = value.toString();
            int length = uuid.length();

            // Checking the length so we don't have the overhead of the regex unless it "looks" like a UUID
            if (length >= 32 && length < 40 && uuidPattern.matcher(uuid).matches()) {
                setUUIDParameter(statement, index, uuid);
                return;
            }
        }

        super.setStringParameter(context, connection, statement, index, value, attribute, type);
    }


    private void setUUIDParameter(final PreparedStatement statement,
                                  final int index, final IRubyObject value) throws SQLException {
        setUUIDParameter(statement, index, value.toString());
    }

    private void setUUIDParameter(final PreparedStatement statement, final int index, String uuid) throws SQLException {

        if (uuid.length() != 36) { // Assume its a non-standard format

            /*
             * Postgres supports a bunch of formats that aren't valid uuids, so we do too...
             * A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11
             * {a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11}
             * a0eebc999c0b4ef8bb6d6bb9bd380a11
             * a0ee-bc99-9c0b-4ef8-bb6d-6bb9-bd38-0a11
             * {a0eebc99-9c0b4ef8-bb6d6bb9-bd380a11}
             */

            if (uuid.length() == 38 && uuid.charAt(0) == '{') {

                // We got the {a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11} version so save some processing
                uuid = uuid.substring(1, 37);

            } else {

                int valueIndex = 0;
                int newUUIDIndex = 0;
                char[] newUUIDChars = new char[36];

                if (uuid.charAt(0) == '{') {
                    // Skip '{'
                    valueIndex++;
                }

                while (newUUIDIndex < 36) { // If we don't hit this before running out of characters it is an invalid UUID

                    char currentChar = uuid.charAt(valueIndex);

                    // Copy anything other than dashes
                    if (currentChar != '-') {
                        newUUIDChars[newUUIDIndex] = currentChar;
                        newUUIDIndex++;

                        // Insert dashes where appropriate
                        if(newUUIDIndex == 8 || newUUIDIndex == 13 || newUUIDIndex == 18 || newUUIDIndex == 23) {
                            newUUIDChars[newUUIDIndex] = '-';
                            newUUIDIndex++;
                        }
                    }

                    valueIndex++;
                }

                uuid = new String(newUUIDChars);

            }
        }

        statement.setObject(index, UUID.fromString(uuid));
    }

    @Override
    protected Integer jdbcTypeFor(final String type) {

        Integer typeValue = POSTGRES_JDBC_TYPE_FOR.get(type);

        if ( typeValue != null ) {
            return typeValue;
        }

        return super.jdbcTypeFor(type);
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

    /**
     * Determines if this field is multiple bits or a single bit (or t/f),
     * if there are multiple bits they are turned into a string, if there
     * is only one it is assumed to be a boolean value
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString of bits or RubyBoolean for a boolean value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject bitToRuby(ThreadContext context, Ruby runtime, ResultSet resultSet, int index) throws SQLException {
        String bits = resultSet.getString(index);

        if (bits == null) return context.nil;
        if (bits.length() > 1) return RubyString.newUnicodeString(context.runtime, bits);

        // We assume it is a boolean value if it doesn't have a length
        return booleanToRuby(context, runtime, resultSet, index);
    }

    /**
     * Converts a JDBC date object to a Ruby date by parsing the string so we can handle edge cases
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject dateToRuby(ThreadContext context, Ruby runtime, ResultSet resultSet, int index) throws SQLException {
        // NOTE: PostgreSQL adapter under MRI using pg gem returns UTC-d Date/Time values
        final String value = resultSet.getString(index);
        if (value == null) return context.nil;

        final int len = value.length();
        if (len < 10 && value.charAt(len - 1) == 'y') { // infinity / -infinity
            IRubyObject infinity = parseInfinity(context.runtime, value);

            if (infinity != null) return infinity;
        }

        return DateTimeUtils.parseDate(context, value, getDefaultTimeZone(context));
    }

    protected IRubyObject decimalToRuby(final ThreadContext context,
                                        final Ruby runtime, final ResultSet resultSet, final int column) throws SQLException {
        if ("NaN".equals(resultSet.getString(column)))  return new RubyBigDecimal(runtime, BigDecimal.ZERO, true);
        return super.decimalToRuby(context, runtime, resultSet, column);
    }

    /**
     * Detects PG specific types and converts them to their Ruby equivalents
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyHash/RubyString/RubyObject
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject objectToRuby(ThreadContext context, Ruby runtime, ResultSet resultSet, int index) throws SQLException {
        final Object object = resultSet.getObject(index);

        if (object == null) return context.nil;

        final Class<?> objectClass = object.getClass();

        if (objectClass == UUID.class) return runtime.newString(object.toString());

        if (object instanceof PGobject) {
            if (objectClass == PGInterval.class) return runtime.newString(formatInterval(object));

            if (objectClass == PGbox.class || objectClass == PGcircle.class ||
                    objectClass == PGline.class || objectClass == PGlseg.class ||
                    objectClass == PGpath.class || objectClass == PGpoint.class ||
                    objectClass == PGpolygon.class ) {
                // AR 5.0+ expects that points don't have the '.0' if it is an integer
                return runtime.newString(pointCleanerPattern.matcher(object.toString()).replaceAll(""));
            }

            // PG 9.2 JSON type will be returned here as well
            return runtime.newString(object.toString());
        }

        if (object instanceof Map) { // hstore
            // by default we avoid double parsing by driver and then column :
            final RubyHash rubyObject = RubyHash.newHash(context.runtime);
            rubyObject.putAll((Map) object); // converts keys/values to ruby
            return rubyObject;
        }

        return JavaUtil.convertJavaToRuby(runtime, object);
    }

    /**
     * Override character stream handling to be read as bytes
     * @param context current thread context
     * @param runtime the Ruby runtime
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject readerToRuby(ThreadContext context, Ruby runtime,
                                       ResultSet resultSet, int index) throws SQLException {
        return stringToRuby(context, runtime, resultSet, index);
    }

    /**
     * Converts a string column into a Ruby string by pulling the raw bytes from the column and
     * turning them into a string using the default encoding
     * @param context current thread context
     * @param runtime the Ruby runtime
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject stringToRuby(ThreadContext context, Ruby runtime, ResultSet resultSet, int index) throws SQLException {
        final byte[] value = resultSet.getBytes(index);

        return value == null ? context.nil : StringHelper.newDefaultInternalString(context.runtime, value);
    }

    /**
     * Converts a JDBC time object to a Ruby time by parsing it as a string
     * @param context current thread context
     * @param runtime the Ruby runtime
     * @param resultSet the jdbc result set to pull the value from
     * @param column the index of the column to convert
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject timeToRuby(ThreadContext context, Ruby runtime, ResultSet resultSet, int column) throws SQLException {
        final String value = resultSet.getString(column); // Using resultSet.getTimestamp(column) only gets .999 (3) precision

        return value == null ? context.nil : DateTimeUtils.parseTime(context, value, getDefaultTimeZone(context));
    }

    /**
     * Converts a JDBC timestamp object to a Ruby time by parsing it as a string
     * @param context current thread context
     * @param runtime the Ruby runtime
     * @param resultSet the jdbc result set to pull the value from
     * @param column the index of the column to convert
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject timestampToRuby(ThreadContext context, Ruby runtime, ResultSet resultSet,
                                          int column) throws SQLException {
        // NOTE: using Timestamp we loose information such as BC :
        // Timestamp: '0001-12-31 22:59:59.0' String: '0001-12-31 22:59:59 BC'
        final String value = resultSet.getString(column);

        if (value == null) return context.nil;

        final int len = value.length();
        if (len < 10 && value.charAt(len - 1) == 'y') { // infinity / -infinity
            IRubyObject infinity = parseInfinity(context.runtime, value);

            if (infinity != null) return infinity;
        }

        // handles '0001-01-01 23:59:59 BC'
        return DateTimeUtils.parseDateTime(context, value, getDefaultTimeZone(context));
    }

    private IRubyObject parseInfinity(final Ruby runtime, final String value) {
        if ("infinity".equals(value)) return RubyFloat.newFloat(runtime,  RubyFloat.INFINITY);
        if ("-infinity".equals(value)) return RubyFloat.newFloat(runtime, -RubyFloat.INFINITY);

        return null;
    }

    // NOTE: do not use PG classes in the API so that loading is delayed !
    private static String formatInterval(final Object object) {
        final PGInterval interval = (PGInterval) object;
        final StringBuilder str = new StringBuilder(32);

        final int years = interval.getYears();
        if (years != 0) str.append(years).append(" years ");

        final int months = interval.getMonths();
        if (months != 0) str.append(months).append(" months ");

        final int days = interval.getDays();
        if (days != 0) str.append(days).append(" days ");

        final int hours = interval.getHours();
        final int mins = interval.getMinutes();
        final int secs = (int) interval.getSeconds();
        if (hours != 0 || mins != 0 || secs != 0) { // xx:yy:zz if not all 00
            if (hours < 10) str.append('0');

            str.append(hours).append(':');

            if (mins < 10) str.append('0');

            str.append(mins).append(':');

            if (secs < 10) str.append('0');

            str.append(secs);

        } else if (str.length() > 1) {
            str.deleteCharAt(str.length() - 1); // " " at the end
        }

        return str.toString();
    }

    // NOTE: without these custom registered Postgre (driver) types
    // ... we can not set range parameters in prepared statements !

    public static class DateRangeType extends PGobject {

        private static final long serialVersionUID = -5378414736244196691L;

        public DateRangeType() {
            setType("daterange");
        }

        public DateRangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class TsRangeType extends PGobject {

        private static final long serialVersionUID = -2991390995527988409L;

        public TsRangeType() {
            setType("tsrange");
        }

        public TsRangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class TstzRangeType extends PGobject {

        private static final long serialVersionUID = 6492535255861743334L;

        public TstzRangeType() {
            setType("tstzrange");
        }

        public TstzRangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class Int4RangeType extends PGobject {

        private static final long serialVersionUID = 4490562039665289763L;

        public Int4RangeType() {
            setType("int4range");
        }

        public Int4RangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class Int8RangeType extends PGobject {

        private static final long serialVersionUID = -1458706215346897102L;

        public Int8RangeType() {
            setType("int8range");
        }

        public Int8RangeType(final String value) throws SQLException {
            this();
            setValue(value);
        }

    }

    public static class NumRangeType extends PGobject {

        private static final long serialVersionUID = 5892509252900362510L;

        public NumRangeType() {
            setType("numrange");
        }

        public NumRangeType(final String value, final String type) throws SQLException {
            setType(type);
            setValue(value);
        }

    }

    @PG @JRubyMethod
    public IRubyObject escape_string(ThreadContext context, IRubyObject string) {
        return PostgreSQLModule.quote_string(context, this, string);
    }

    @PG @JRubyMethod(name = "typemap=")
    public IRubyObject typemap_set(ThreadContext context, IRubyObject mapArg) {
        if (mapArg.isNil()) {
            typeMap = null;
            return context.nil;
        }

        TypeConverter.checkHashType(context.runtime, mapArg);
        this.typeMap = (RubyHash) mapArg;
        return mapArg;
    }
}
