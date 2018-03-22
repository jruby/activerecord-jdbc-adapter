package arjdbc.jdbc;

import arjdbc.jdbc.types.AbstractType;
import arjdbc.jdbc.types.BigIntegerType;
import arjdbc.jdbc.types.BinaryType;
import arjdbc.jdbc.types.BooleanType;
import arjdbc.jdbc.types.CharacterStreamType;
import arjdbc.jdbc.types.DateType;
import arjdbc.jdbc.types.DecimalType;
import arjdbc.jdbc.types.DoubleType;
import arjdbc.jdbc.types.IntegerType;
import arjdbc.jdbc.types.NullType;
import arjdbc.jdbc.types.ObjectType;
import arjdbc.jdbc.types.StringType;
import arjdbc.jdbc.types.XMLType;

import java.io.IOException;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * This is a base Result class to be returned as the "raw" result.
 * It should be overridden for specific adapters to manage type maps
 * and provide any additional methods needed.
 */
public class JdbcResult extends RubyObject {

    // Should these be private with accessors?
    protected final AbstractType[] columns;
    protected final RubyArray values;
    protected RubyHash[] tuples;

    protected JdbcResult(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
        columns = new AbstractType[0];
        values = runtime.newEmptyArray();
    }

    protected JdbcResult(Ruby runtime, RubyClass metaClass, final ThreadContext context,
            final ResultSet resultSet) throws SQLException {
        super(runtime, metaClass);
        values = runtime.newArray();
        columns = extractColumns(context, resultSet.getMetaData());
        processResultSet(context, resultSet);
    }

    private RubyArray columnNames(final ThreadContext context) {
        final RubyString[] columnNames = new RubyString[columns.length];

        for (int i = 0; i < columns.length; i++) {
            columnNames[i] = columns[i].getName(context);
        }

        return RubyArray.newArrayNoCopy(context.runtime, columnNames);
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

    /**
     * Build an array of column types
     * @param context current thread context
     * @param resultMetaData metadata from a ResultSet to determine column information from
     * @return an array of column types
     * @throws SQLException
     */
    private AbstractType[] extractColumns(final ThreadContext context,
            final ResultSetMetaData resultMetaData) throws SQLException {

        final int columnCount = resultMetaData.getColumnCount();
        final AbstractType[] columns = new AbstractType[columnCount];

        for (int i = 1; i <= columnCount; i++) { // metadata is one-based
            String name = resultMetaData.getColumnLabel(i);
            // This appears to not be used by Postgres, MySQL, or SQLite so leaving it off for now
            //name = caseConvertIdentifierForRails(connection, name);

            final int columnType = resultMetaData.getColumnType(i);
            columns[i - 1] = getColumnType(name, columnType, i);
        }

        return columns;
    }

    /**
     * Create a column type object for the given column type.
     * It is overridden by subclasses to allow adapters to have different mapping strategies
     * @param name the name of the column
     * @param columnType the identifier for the column type
     * @param index the index of the column in the row
     * @return an initialized column type
     */
    protected AbstractType getColumnType(String name, int columnType, int index) {
        switch (columnType) {
            case Types.BIGINT:
                return new BigIntegerType(name, index);
            case Types.BIT:
            case Types.BOOLEAN:
                return new BooleanType(name, index);
            case Types.BLOB:
            case Types.BINARY:
            case Types.VARBINARY:
            case Types.LONGVARBINARY:
                return new BinaryType(name, index);
            case Types.CLOB:
            case Types.NCLOB:
            case Types.LONGVARCHAR:
            case Types.LONGNVARCHAR:
                return new CharacterStreamType(name, index);
            case Types.DATE:
                return new DateType(name, index);
            case Types.DECIMAL:
            case Types.NUMERIC:
                return new DecimalType(name, index);
            case Types.DOUBLE:
            case Types.FLOAT:
            case Types.REAL:
                return new DoubleType(name, index);
            case Types.INTEGER:
            case Types.SMALLINT:
            case Types.TINYINT:
                return new IntegerType(name, index);
            case Types.JAVA_OBJECT:
            case Types.OTHER:
                return new ObjectType(name, index);
            case Types.NULL:
                return new NullType(name, index);
            case Types.SQLXML:
                return new XMLType(name, index);
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
        return new StringType(name, index);
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::Result</code>
     */
    private RubyClass getResultClass(final Ruby runtime) {
        return (RubyClass) runtime.getModule("ActiveRecord").getConstantAt("Result");
    }

    /**
     * Builds an array of hashes with column names to column values
     * @param context current thread context
     */
    protected void populateTuples(final ThreadContext context) {
        int columnCount = columns.length;
        tuples = new RubyHash[values.size()];

        for (int i = 0; i < tuples.length; i++) {
            RubyArray currentRow = (RubyArray) values.eltInternal(i);
            RubyHash hash = RubyHash.newHash(context.runtime);
            for (int columnIndex = 0; columnIndex < columnCount; columnIndex++) {
                hash.fastASet(columns[columnIndex].getName(context), currentRow.eltInternal(columnIndex));
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
        int columnCount = columns.length;

        while (resultSet.next()) {
            final IRubyObject[] row = new IRubyObject[columnCount];

            for (int i = 0; i < columnCount; i++) {
                row[i] = columns[i].extractRubyValue(context, resultSet);
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
        final RubyClass Result = getResultClass(context.runtime);
        return Result.newInstance(context, columnNames(context), values, columnTypeMap(context), Block.NULL_BLOCK);
    }

}
