package arjdbc.postgresql;

import arjdbc.jdbc.JdbcResult;
import arjdbc.util.DateTimeUtils;
import arjdbc.util.StringHelper;

import java.lang.StringBuilder;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyFloat;
import org.jruby.RubyHash;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.postgresql.core.Field;
import org.postgresql.geometric.PGbox;
import org.postgresql.geometric.PGcircle;
import org.postgresql.geometric.PGline;
import org.postgresql.geometric.PGlseg;
import org.postgresql.geometric.PGpath;
import org.postgresql.geometric.PGpoint;
import org.postgresql.geometric.PGpolygon;
import org.postgresql.jdbc.PgResultSetMetaData;
import org.postgresql.jdbc.PgResultSetMetaDataWrapper; // This is a hack unfortunately to get around method scoping
import org.postgresql.util.PGInterval;
import org.postgresql.util.PGobject;


/*
 * This class mimics the PG:Result class enough to get by
 */
public class PostgreSQLResult extends JdbcResult {

    // Used to wipe trailing 0's from points (3.0, 5.6) -> (3, 5.6)
    private static final Pattern pointCleanerPattern = Pattern.compile("\\.0\\b");

    // These are needed when generating an AR::Result
    private IRubyObject adapter;
    private PgResultSetMetaData resultSetMetaData;

    /********* JRuby compat methods ***********/

    private static RubyClass rubyClass;
    protected static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new PostgreSQLResult(runtime, klass);
        }
    };

    public static RubyClass createPostgreSQLResultClass(Ruby runtime, RubyClass postgreSQLConnection) {
        rubyClass = postgreSQLConnection.defineClassUnder("Result", runtime.getObject(), ALLOCATOR);
        rubyClass.defineAnnotatedMethods(PostgreSQLResult.class);
        rubyClass.includeModule(runtime.getEnumerable());
        return rubyClass;
    }

    /**
     * Generates a new PostgreSQLResult object for the given result set
     * @param context current thread context
     * @param resultSet the set of results that should be returned
     * @param adapter a reference to the current adapter, this is needed for generating an AR::Result object
     * @return an instantiated result object
     * @throws SQLException
     */
    public static PostgreSQLResult newResult(final ThreadContext context,
            final ResultSet resultSet, final IRubyObject adapter) throws SQLException {
        return new PostgreSQLResult(context.runtime, rubyClass, context, resultSet, adapter);
    }

    /********* End JRuby compat methods ***********/

    protected PostgreSQLResult(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    private PostgreSQLResult(Ruby runtime, RubyClass metaClass, final ThreadContext context,
            final ResultSet resultSet, final IRubyObject adapter) throws SQLException {
        super(runtime, metaClass, context, resultSet);
        this.adapter = adapter;
        resultSetMetaData = (PgResultSetMetaData) resultSet.getMetaData();
    }

    /**
     * Generates a type map to be given to the AR::Result object
     * @param context current thread context
     * @return RubyHash(RubyString - column name, Type::Value - type object)
     * @throws SQLException if it fails to get the field
     */
    @Override
    protected IRubyObject columnTypeMap(final ThreadContext context) throws SQLException{
        final RubyString[] rubyColumnNames = getColumnNames(context);
        RubyHash types = RubyHash.newHash(context.runtime);
        PgResultSetMetaDataWrapper mdWrapper = new PgResultSetMetaDataWrapper(resultSetMetaData);

        for (int i = 0; i < rubyColumnNames.length; i++) {
            final Field field = mdWrapper.getField(i + 1);
            final RubyString name = rubyColumnNames[i];

            final IRubyObject[] args = {
                context.runtime.newFixnum(field.getOID()),
                context.runtime.newFixnum(field.getMod()),
                name
            };
            final IRubyObject type = adapter.callMethod(context, "get_oid_type", args);

            if (!type.isNil()) {
                types.fastASet(name, type);
            }
        }

        return types;
    }

    /**
     * This is to support the Enumerable module.
     * This is needed when setting up the type maps so the Enumerable methods work
     * @param context
     * @param block
     * @return this object or RubyNil
     */
    @JRubyMethod
    public IRubyObject each(ThreadContext context, Block block) {
        // At this point we don't support calling this without a block
        if (block.isGiven()) {
            if (tuples == null) {
                populateTuples(context);
            }

            for (int i = 0; i < tuples.length; i++) {
                block.yield(context, tuples[i]);
            }

            return this;
        } else {
            return context.nil;
        }
    }

    /**
     * Returns an array of arrays of the values in the result.
     * This is defined in PG::Result and is used by some Rails tests
     * @return IRubyObject RubyArray of RubyArray of values
     */
    @JRubyMethod
    public IRubyObject values() {
        return values;
    }


    /***********************************************************************************************
     ************************************** Converter Methods **************************************
     ***********************************************************************************************/

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
    protected IRubyObject bitToRuby(final ThreadContext context, final ResultSet resultSet,
                                    int index) throws SQLException {
        final String bits = resultSet.getString(index);

        if (bits == null) {
            return context.nil;
        }

        if (bits.length() > 1) {
            return RubyString.newUnicodeString(context.runtime, bits);
        }

        // We assume it is a boolean value if it doesn't have a length
        return booleanToRuby(context, resultSet, index);
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
    protected IRubyObject dateToRuby(final ThreadContext context, final ResultSet resultSet,
                                     int index) throws SQLException {
        // NOTE: PostgreSQL adapter under MRI using pg gem returns UTC-d Date/Time values
        final String value = resultSet.getString(index);

        if (value == null) {
            return context.nil;
        }

        return DateTimeUtils.parseDate(context, value, getDefaultTimeZone(context));
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
    protected IRubyObject objectToRuby(final ThreadContext context, final ResultSet resultSet,
                                    int index) throws SQLException {
        final Object object = resultSet.getObject(index);

        if (object == null) {
            return context.nil;
        }

        final Ruby runtime = context.runtime;
        final Class<?> objectClass = object.getClass();

        if (objectClass == UUID.class) {
            return runtime.newString(object.toString());
        }

        if (object instanceof PGobject) {

            if (objectClass == PGInterval.class) {
                return runtime.newString(formatInterval(object));
            }

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
     * Converts a string column into a Ruby string by pulling the raw bytes from the column and
     * turning them into a string using the default encoding
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject stringToRuby(final ThreadContext context, final ResultSet resultSet,
                                    int index) throws SQLException {
        final byte[] value = resultSet.getBytes(index);

        if (value == null) {
            return context.nil;
        }

        return StringHelper.newDefaultInternalString(context.runtime, value);
    }

    /**
     * Converts a JDBC time object to a Ruby time by parsing it as a string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject timeToRuby(final ThreadContext context, final ResultSet resultSet,
                                     final int column) throws SQLException {
        final String value = resultSet.getString(column);
        // extracting with resultSet.getTimestamp(column) only gets .999 (3) precision
        if (value == null) {
            return context.nil;
        }

        return DateTimeUtils.parseTime(context, value, getDefaultTimeZone(context));
    }

    /**
     * Converts a JDBC timestamp object to a Ruby time by parsing it as a string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    protected IRubyObject timestampToRuby(final ThreadContext context, final ResultSet resultSet,
                                          final int column) throws SQLException {
        // NOTE: using Timestamp we loose information such as BC :
        // Timestamp: '0001-12-31 22:59:59.0' String: '0001-12-31 22:59:59 BC'
        final String value = resultSet.getString(column);

        if (value == null) {
            return context.nil;
        }

        final int len = value.length();
        if (len < 10 && value.charAt(len - 1) == 'y') { // infinity / -infinity
            IRubyObject infinity = parseInfinity(context.runtime, value);

            if (infinity != null) {
                return infinity;
            }
        }

        return DateTimeUtils.parseDateTime(context, value, getDefaultTimeZone(context));
    }

    // NOTE: do not use PG classes in the API so that loading is delayed !
    private static String formatInterval(final Object object) {
        final PGInterval interval = (PGInterval) object;
        final StringBuilder str = new StringBuilder(32);

        final int years = interval.getYears();
        if (years != 0) {
            str.append(years).append(" years ");
        }

        final int months = interval.getMonths();
        if (months != 0) {
            str.append(months).append(" months ");
        }

        final int days = interval.getDays();
        if (days != 0) {
            str.append(days).append(" days ");
        }

        final int hours = interval.getHours();
        final int mins = interval.getMinutes();
        final int secs = (int) interval.getSeconds();
        if (hours != 0 || mins != 0 || secs != 0) { // xx:yy:zz if not all 00

            if (hours < 10) {
                str.append('0');
            }

            str.append(hours).append(':');

            if (mins < 10) {
                str.append('0');
            }

            str.append(mins).append(':');

            if (secs < 10) {
                str.append('0');
            }

            str.append(secs);

        } else if (str.length() > 1) {
            str.deleteCharAt(str.length() - 1); // " " at the end
        }

        return str.toString();
    }

    private IRubyObject parseInfinity(final Ruby runtime, final String value) {
        if ("infinity".equals(value)) {
            return RubyFloat.newFloat(runtime,  RubyFloat.INFINITY);
        }
        if ("-infinity".equals(value)) {
            return RubyFloat.newFloat(runtime, -RubyFloat.INFINITY);
        }
        return null;
    }

}
