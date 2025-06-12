package arjdbc.jdbc;

import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import static org.jruby.api.Create.newArray;
import static org.jruby.api.Create.newArrayNoCopy;
import static org.jruby.api.Create.newHash;

/**
 * This is a base Result class to be returned as the "raw" result.
 * It should be overridden for specific adapters to manage type maps
 * and provide any additional methods needed.
 */
public class JdbcResult extends RubyObject {
    // Should these be private with accessors?
    protected final RubyArray values;
    protected RubyHash[] tuples;

    protected final int[] columnTypes;
    protected RubyString[] columnNames;
    protected final RubyJdbcConnection connection;

    protected JdbcResult(ThreadContext context, RubyClass clazz, RubyJdbcConnection connection, ResultSet resultSet) throws SQLException {
        super(context.runtime, clazz);

        values = newArray(context);
        this.connection = connection;

        final ResultSetMetaData resultMetaData = resultSet.getMetaData();
        final int columnCount = resultMetaData.getColumnCount();
        // FIXME: if we support MSSQL we may need to change how we deal with omitting elements
        columnNames = new RubyString[columnCount];
        columnTypes = new int[columnCount];
        extractColumnInfo(context, resultMetaData);
        processResultSet(context, resultSet);
    }

    /**
     * Builds a type map for creating the AR::Result, most adapters don't need it
     * @param context which thread this is running on.
     * @return RubyNil
     * @throws SQLException postgres result can throw an exception
     */
    protected IRubyObject columnTypeMap(ThreadContext context) throws SQLException {
        return context.nil;
    }

    /**
     * Build an array of column types
     * @param resultMetaData metadata from a ResultSet to determine column information from
     * @throws SQLException throws error!
     */
    private void extractColumnInfo(ThreadContext context, ResultSetMetaData resultMetaData) throws SQLException {
        final int columnCount = resultMetaData.getColumnCount();

        for (int i = 1; i <= columnCount; i++) { // metadata is one-based
            // This appears to not be used by Postgres, MySQL, or SQLite so leaving it off for now
            //name = caseConvertIdentifierForRails(connection, name);
            columnNames[i - 1] = RubyJdbcConnection.STRING_CACHE.get(context, resultMetaData.getColumnLabel(i));
            columnTypes[i - 1] = resultMetaData.getColumnType(i);
        }
    }

    /**
     * @return an array with the column names as Ruby strings
     */
    protected RubyString[] getColumnNames() {
        return columnNames;
    }

    /**
     * Builds an array of hashes with column names to column values
     * @param context current thread context
     */
    protected void populateTuples(final ThreadContext context) {
        int columnCount = columnNames.length;
        tuples = new RubyHash[values.size()];

        for (int i = 0; i < tuples.length; i++) {
            RubyArray currentRow = (RubyArray) values.eltInternal(i);
            RubyHash hash = newHash(context);
            for (int columnIndex = 0; columnIndex < columnCount; columnIndex++) {
                hash.fastASet(columnNames[columnIndex], currentRow.eltInternal(columnIndex));
            }
            tuples[i] = hash;
        }
    }

    /**
     * Does the heavy lifting of turning the JDBC objects into Ruby objects
     * @param context current thread context
     * @param resultSet the set of results we are converting
     * @throws SQLException throws!
     */
    private void processResultSet(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        int columnCount = columnNames.length;

        while (resultSet.next()) {
            final IRubyObject[] row = new IRubyObject[columnCount];

            for (int i = 0; i < columnCount; i++) {
                row[i] = connection.jdbcToRuby(context, context.runtime, i + 1, columnTypes[i], resultSet); // Result Set is 1 based
            }

            values.append(context, newArrayNoCopy(context, row));
        }
    }

    /**
     * Creates an <code>ActiveRecord::Result</code> with the data from this result
     * @param context current thread context
     * @return ActiveRecord::Result object with the data from this result set
     * @throws SQLException can be caused by postgres generating its type map
     */
    public IRubyObject toARResult(final ThreadContext context) throws SQLException {
        final RubyClass Result = RubyJdbcConnection.getResult(context);
        // FIXME: Is this broken?  no copy of an array AR::Result can modify?  or should it be frozen?
        final RubyArray rubyColumnNames = newArrayNoCopy(context, getColumnNames());
        return Result.newInstance(context, rubyColumnNames, values, columnTypeMap(context), Block.NULL_BLOCK);
    }
}
