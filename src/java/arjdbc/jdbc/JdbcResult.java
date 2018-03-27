package arjdbc.jdbc;

import arjdbc.util.ActiveRecord;
import arjdbc.util.DateTimeUtils;
import arjdbc.util.StringCache;
import arjdbc.util.StringHelper;

import java.io.IOException;
import java.io.InputStream;
import java.io.Reader;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.sql.Array;
import java.sql.Connection;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.SQLXML;
import java.sql.Time;
import java.sql.Timestamp;
import java.sql.Types;

import org.joda.time.DateTimeZone;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBignum;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.ext.bigdecimal.RubyBigDecimal;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.callsite.CachingCallSite;
import org.jruby.runtime.callsite.FunctionalCachingCallSite;
import org.jruby.util.ByteList;

/**
 * This is a base Result class to be returned as the "raw" result.
 * It should be overridden for specific adapters to manage type maps
 * and provide any additional methods needed.
 */
public class JdbcResult extends RubyObject {

    private static final StringCache STRING_CACHE = new StringCache();
    private static int streamBufferSize = 1024;

    // Should these be private with accessors?
    protected final RubyArray values;
    protected RubyHash[] tuples;

    private final String[] columnNames;
    private final int[] columnTypes;
    private RubyString[] rubyColumnNames;

    protected JdbcResult(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
        columnNames = new String[0];
        columnTypes = new int[0];
        values = runtime.newEmptyArray();
    }

    protected JdbcResult(Ruby runtime, RubyClass metaClass, final ThreadContext context,
            final ResultSet resultSet) throws SQLException {
        super(runtime, metaClass);
        values = runtime.newArray();

        final ResultSetMetaData resultMetaData = resultSet.getMetaData();
        final int columnCount = resultMetaData.getColumnCount();
        columnNames = new String[columnCount];
        columnTypes = new int[columnCount];
        extractColumnInfo(context, resultMetaData);
        processResultSet(context, resultSet);
    }

    /**
     * Builds a type map for creating the AR::Result, most adapters don't need it
     * @param context
     * @return RubyNil
     * @throws SQLException postgres result can throw an exception
     */
    protected IRubyObject columnTypeMap(final ThreadContext context) throws SQLException {
        return context.nil;
    }

    protected IRubyObject jdbcToRuby(final ThreadContext context, final ResultSet resultSet,
                                     int columnType, int index) throws SQLException {
        switch (columnType) {
            case Types.ARRAY:
                return arrayToRuby(context, resultSet, index);
            case Types.BIGINT:
                return bigIntToRuby(context, resultSet, index);
            case Types.BINARY:
            case Types.VARBINARY:
            case Types.LONGVARBINARY:
                return binaryToRuby(context, resultSet, index);
            case Types.BIT:
                return bitToRuby(context, resultSet, index);
            case Types.BOOLEAN:
                return booleanToRuby(context, resultSet, index);
            case Types.BLOB:
                return blobToRuby(context, resultSet, index);
            case Types.CLOB:
            case Types.NCLOB:
                return clobToRuby(context, resultSet, index);
            case Types.DATE:
                return dateToRuby(context, resultSet, index);
            case Types.DECIMAL:
                return decimalToRuby(context, resultSet, index);
            case Types.DOUBLE:
            case Types.FLOAT:
            case Types.REAL:
                return doubleToRuby(context, resultSet, index);
            case Types.INTEGER:
            case Types.SMALLINT:
            case Types.TINYINT:
                return integerToRuby(context, resultSet, index);
            case Types.JAVA_OBJECT:
            case Types.OTHER:
                return objectToRuby(context, resultSet, index);
            case Types.LONGVARCHAR:
            case Types.LONGNVARCHAR:
                return longVarcharToRuby(context, resultSet, index);
            case Types.NULL:
                return nullToRuby(context, resultSet, index);
            case Types.NUMERIC:
                return numericToRuby(context, resultSet, index);
            case Types.SQLXML:
                return xmlToRuby(context, resultSet, index);
            case Types.TIME:
                return timeToRuby(context, resultSet, index);
            case Types.TIMESTAMP:
                return timestampToRuby(context, resultSet, index);
        }

        /*
         * Treat these and anything else as a string
         *  case Types.CHAR:
         *  case Types.VARCHAR:
         *  case Types.NCHAR:
         *  case Types.NVARCHAR:
         *  case Types.DISTINCT:
         *  case Types.STRUCT:
         *  case Types.REF:
         *  case Types.DATALINK:
         */
        return stringToRuby(context, resultSet, index);
    }

    /**
     * Build an array of column types
     * @param context current thread context
     * @param resultMetaData metadata from a ResultSet to determine column information from
     * @return an array of column types
     * @throws SQLException
     */
    private void extractColumnInfo(final ThreadContext context,
                                   final ResultSetMetaData resultMetaData) throws SQLException {

        final int columnCount = resultMetaData.getColumnCount();

        for (int i = 1; i <= columnCount; i++) { // metadata is one-based
            // This appears to not be used by Postgres, MySQL, or SQLite so leaving it off for now
            //name = caseConvertIdentifierForRails(connection, name);
            columnNames[i - 1] = resultMetaData.getColumnLabel(i);
            columnTypes[i - 1] = resultMetaData.getColumnType(i);
        }
    }

    /**
     * @param context the current thread context
     * @return an array with the column names as Ruby strings
     */
    protected RubyString[] getColumnNames(final ThreadContext context) {
        if (rubyColumnNames == null) {
            rubyColumnNames = new RubyString[columnNames.length];

            for (int i = 0; i < columnNames.length; i++) {
                rubyColumnNames[i] = STRING_CACHE.get(context, columnNames[i]);
            }
        }

        return rubyColumnNames;
    }

    /**
     * Builds an array of hashes with column names to column values
     * @param context current thread context
     */
    protected void populateTuples(final ThreadContext context) {
        final RubyString[] rubyColumnNames = getColumnNames(context);
        int columnCount = rubyColumnNames.length;
        tuples = new RubyHash[values.size()];

        for (int i = 0; i < tuples.length; i++) {
            RubyArray currentRow = (RubyArray) values.eltInternal(i);
            RubyHash hash = RubyHash.newHash(context.runtime);
            for (int columnIndex = 0; columnIndex < columnCount; columnIndex++) {
                hash.fastASet(rubyColumnNames[columnIndex], currentRow.eltInternal(columnIndex));
            }
            tuples[i] = hash;
        }
    }

    /**
     * Does the heavy lifting of turning the JDBC objects into Ruby objects
     * @param context current thread context
     * @param resultSet the set of results we are converting
     * @throws SQLException
     */
    private void processResultSet(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        int columnCount = columnNames.length;

        while (resultSet.next()) {
            final IRubyObject[] row = new IRubyObject[columnCount];

            for (int i = 0; i < columnCount; i++) {
                row[i] = jdbcToRuby(context, resultSet, columnTypes[i], i + 1); // Result Set is 1 based
            }

            values.append(RubyArray.newArrayNoCopy(context.runtime, row));
        }
    }

    /**
     * Creates an <code>ActiveRecord::Result</code> with the data from this result
     * @param context current thread context
     * @return ActiveRecord::Result object with the data from this result set
     * @throws SQLException can be caused by postgres generating its type map
     */
    public IRubyObject toARResult(final ThreadContext context) throws SQLException {
        final RubyClass Result = ActiveRecord.Result(context);
        final RubyArray rubyColumnNames = RubyArray.newArrayNoCopy(context.runtime, getColumnNames(context));
        return Result.newInstance(context, rubyColumnNames, values, columnTypeMap(context), Block.NULL_BLOCK);
    }

    /***********************************************************************************************
     ************************************** Converter Methods **************************************
     ***********************************************************************************************/

    /**
     * Recursively converts an array column into a Ruby array
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyBignum if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject arrayToRuby(final ThreadContext context, final ResultSet resultSet,
                                      final int index) throws SQLException {
        final Array value = resultSet.getArray(index);

        if (value == null) {
            return context.nil;
        }

        try {

            final RubyArray array = context.runtime.newArray();
            final ResultSet arrayResult = value.getResultSet();
            final int baseType = value.getBaseType();

            while (arrayResult.next()) {
                array.append(jdbcToRuby(context, arrayResult, baseType, 2)); // column 1: index, column 2: value
            }

            return array;

        } finally {
            value.free();
        }
    }

    /**
     * Converts a large integer column into a Ruby bignum
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyBignum if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject bigIntToRuby(final ThreadContext context, final ResultSet resultSet,
                                       int index) throws SQLException {
        final String value = resultSet.getString(index);

        if (value == null) {
            return context.nil;
        }

        return RubyBignum.bignorm(context.runtime, new BigInteger(value));
    }

    /**
     * Converts a binary column into a Ruby string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject binaryToRuby(final ThreadContext context, final ResultSet resultSet,
                                       int index) throws SQLException {
        final InputStream stream = resultSet.getBinaryStream(index);

        if (stream == null) {
            return context.nil;
        }

        // We nest these because the #close call in the finally block can throw an IOException
        try {
            try {
                final int bufferSize = streamBufferSize;
                final ByteList bytes = new ByteList(bufferSize);

                StringHelper.readBytes(bytes, stream, bufferSize);

                return context.runtime.newString(bytes);
            } finally {
                stream.close();
            }
        } catch (IOException e) {
            throw new SQLException(e.getMessage(), e);
        }
    }

    /**
     * Converts a bit column to its Ruby equivalent.
     * Defaults to treating it as a boolean value.
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyBoolean if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject bitToRuby(final ThreadContext context, final ResultSet resultSet,
                                    int index) throws SQLException {
        return booleanToRuby(context, resultSet, index);
    }

    /**
     * Converts a BLOB column into its Ruby equivalent.
     * Defaults to treating it as a binary column {@link #binaryToRuby(ThreadContext, ResultSet, int)}
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject blobToRuby(final ThreadContext context, final ResultSet resultSet,
                                     int index) throws SQLException {
        return binaryToRuby(context, resultSet, index);
    }

    /**
     * Converts a boolean column into a Ruby boolean
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyBoolean if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject booleanToRuby(final ThreadContext context, final ResultSet resultSet,
                                        int index) throws SQLException {
        final boolean value = resultSet.getBoolean(index);

        if (value == false && resultSet.wasNull()) {
            return context.nil;
        }

        return context.runtime.newBoolean(value);
    }

    /**
     * Converts a CLOB column into a Ruby string.
     * Defaults to using a <code>Reader</code> object {@link #readerToRuby(ThreadContext, ResultSet, int)}
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject clobToRuby(final ThreadContext context, final ResultSet resultSet,
                                     int index) throws SQLException {
        return readerToRuby(context, resultSet, index);
    }

    /**
     * Converts a JDBC date object to a Ruby date
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject dateToRuby(final ThreadContext context, final ResultSet resultSet,
                                     int index) throws SQLException {

        final Date value = resultSet.getDate(index);

        // This previously returned an empty string here if 'wasNull()' was false
        // so if we see odd behavior that may need to be added back
        if (value == null) {
            return context.nil;
        }

        return DateTimeUtils.newDateAsTime(context, value, null).callMethod(context, "to_date");
    }

    /**
     * Converts a decimal column into a Ruby big decimal
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyBigDecimal if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject decimalToRuby(final ThreadContext context, final ResultSet resultSet,
                                        int index) throws SQLException {
        final BigDecimal value = resultSet.getBigDecimal(index);

        if (value == null) {
            return context.nil;
        }

        return new RubyBigDecimal(context.runtime, value);
    }

    /**
     * Converts a floating point column into a Ruby float
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyFloat if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject doubleToRuby(final ThreadContext context, final ResultSet resultSet,
                                       int index) throws SQLException {
        final double value = resultSet.getDouble(index);

        if (value == 0 && resultSet.wasNull()) {
            return context.nil;
        }

        return context.runtime.newFloat(value);
    }

    /**
     * Converts an integer column into a Ruby integer.
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyInteger if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject integerToRuby(final ThreadContext context, final ResultSet resultSet,
                                        int index) throws SQLException {
        final long value = resultSet.getLong(index);

        if (value == 0 && resultSet.wasNull()) {
            return context.nil;
        }

        return context.runtime.newFixnum(value);
    }

    /**
     * Converts a long varchar column into a Ruby string.
     * Defaults to using a <code>Reader</code> object {@link #readerToRuby(ThreadContext, ResultSet, int)}
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject longVarcharToRuby(final ThreadContext context, final ResultSet resultSet,
                                            int index) throws SQLException {
        return readerToRuby(context, resultSet, index);
    }

    /**
     * Converts a numeric column into its Ruby equivalent.
     * Defaults to treating it as a decimal {@link #decimalToRuby(ThreadContext, ResultSet, int)}
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyBigDecimal if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject numericToRuby(final ThreadContext context, final ResultSet resultSet,
                                        int index) throws SQLException {
        return decimalToRuby(context, resultSet, index);
    }

    /**
     * Assumes this column is always NULL
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject nullToRuby(final ThreadContext context, final ResultSet resultSet,
                                           int index) throws SQLException {
        return context.nil;
    }

    /**
     * Converts the column into a RubyObject
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyObject if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject objectToRuby(final ThreadContext context, final ResultSet resultSet,
                                       int index) throws SQLException {
        final Object value = resultSet.getObject(index);

        if (value == null) {
            return context.nil;
        }

        return JavaUtil.convertJavaToRuby(context.runtime, value);
    }

    /**
     * Converts a column that is handled as a Reader object into a Ruby string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject readerToRuby(final ThreadContext context, final ResultSet resultSet,
                                     int index) throws SQLException {
        final Reader reader = resultSet.getCharacterStream(index);

        if (reader == null) {
            return context.nil;
        }

        // We nest these because the #close call can throw an IOException
        try {
            try {
                final int bufferSize = streamBufferSize;
                final StringBuilder string = new StringBuilder(bufferSize);

                final char[] buffer = new char[bufferSize];

                int len = reader.read(buffer);
                while (len != -1) {
                    string.append(buffer, 0, len);
                    len = reader.read(buffer);
                }

                return RubyString.newInternalFromJavaExternal(context.runtime, string.toString());
            } finally {
                reader.close();
            }
        } catch (IOException e) {
            throw new SQLException(e.getMessage(), e);
        }
    }

    /**
     * Converts a string column into a Ruby string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject stringToRuby(final ThreadContext context, final ResultSet resultSet,
                                       int index) throws SQLException {
        final String value = resultSet.getString(index);

        if (value == null) {
            return context.nil;
        }

        return RubyString.newInternalFromJavaExternal(context.runtime, value);
    }

    /**
     * Converts a JDBC time object to a Ruby time
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject timeToRuby(final ThreadContext context, final ResultSet resultSet,
                                     final int column) throws SQLException {
        final Time value = resultSet.getTime(column);

        // This previously returned an empty string here if 'wasNull()' was false
        // so if we see odd behavior that may need to be added back
        if (value == null) {
            return context.nil;
        }

        return DateTimeUtils.newDummyTime(context, value, getDefaultTimeZone(context));
    }

    /**
     * Converts a JDBC timestamp object to a Ruby time
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject timestampToRuby(final ThreadContext context, final ResultSet resultSet,
                                          final int column) throws SQLException {
        final Timestamp value = resultSet.getTimestamp(column);

        // This previously returned an empty string here if 'wasNull()' was false
        // so if we see odd behavior that may need to be added back
        if (value == null) {
            return context.nil;
        }

        // NOTE: with 'raw' String AR's Type::DateTime does put the time in proper time-zone
        // while when returning a Time object it just adjusts usec (apply_seconds_precision)
        // yet for custom SELECTs to work (SELECT created_at ... ) and for compatibility we
        // should be returning Time (by default) - AR does this by adjusting mysql2/pg returns

        return DateTimeUtils.newTime(context, value, getDefaultTimeZone(context));
    }

    protected DateTimeZone getDefaultTimeZone(final ThreadContext context) {
        return isDefaultTimeZoneUTC(context) ? DateTimeZone.UTC : DateTimeZone.getDefault();
    }

    private boolean isDefaultTimeZoneUTC(final ThreadContext context) {
        return "utc".equalsIgnoreCase(default_timezone(context));
    }

    // ActiveRecord::Base.default_timezone
    private static final CachingCallSite default_timezone = new FunctionalCachingCallSite("default_timezone");

    private static String default_timezone(final ThreadContext context) {
        final RubyClass base = ActiveRecord.Base(context);
        return default_timezone.call(context, base, base).toString(); // :utc (or :local)
    }


    /**
     * Converts an XML column into a Ruby string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @param index the index of the column to convert
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    protected IRubyObject xmlToRuby(final ThreadContext context, final ResultSet resultSet,
                                    int index) throws SQLException {
        final SQLXML value = resultSet.getSQLXML(index);

        if (value == null) {
            return context.nil;
        }

        try {
            return RubyString.newInternalFromJavaExternal(context.runtime, value.getString());
        } finally {
            value.free();
        }
    }

}
