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

/**
 * This is a base Result class to be returned as the "raw" result.
 * It should be overridden for specific adapters to manage type maps
 * and provide any additional methods needed.
 */
public class JdbcResult extends RubyObject {
    // Should these be private with accessors?
    protected final RubyArray values;
    protected RubyHash[] tuples;

    private final String[] columnNames;
    private final int[] columnTypes;
    private RubyString[] rubyColumnNames;
    private final RubyJdbcConnection connection;

    protected JdbcResult(ThreadContext context, RubyClass clazz, RubyJdbcConnection connection, ResultSet resultSet) throws SQLException {
        super(context.runtime, clazz);

        values = context.runtime.newArray();
        this.connection = connection;

        final ResultSetMetaData resultMetaData = resultSet.getMetaData();
        final int columnCount = resultMetaData.getColumnCount();
        columnNames = new String[columnCount];
        columnTypes = new int[columnCount];
        extractColumnInfo(resultMetaData);
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
    private void extractColumnInfo(ResultSetMetaData resultMetaData) throws SQLException {
        final int columnCount = resultMetaData.getColumnCount();

        for (int i = 1; i <= columnCount; i++) { // metadata is one-based
            // This appears to not be used by Postgres, MySQL, or SQLite so leaving it off for now
            //name = caseConvertIdentifierForRails(connection, name);
            columnNames[i - 1] = resultMetaData.getColumnLabel(i);
            columnTypes[i - 1] = resultMetaData.getColumnType(i);
        }
    }

    /**
     * @param runtime the ruby runtime
     * @return <code>ActiveRecord::Result</code>
     */
    private RubyClass getActiveRecordResultClass(final Ruby runtime) {
        return (RubyClass) runtime.getModule("ActiveRecord").getConstantAt("Result");
    }

    /**
     * @param context the current thread context
     * @return an array with the column names as Ruby strings
     */
    protected RubyString[] getColumnNames(final ThreadContext context) {
        if (rubyColumnNames == null) {
            rubyColumnNames = new RubyString[columnNames.length];

            for (int i = 0; i < columnNames.length; i++) {
                rubyColumnNames[i] = RubyJdbcConnection.STRING_CACHE.get(context, columnNames[i]);
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
     * @throws SQLException throws!
     */
    private void processResultSet(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        Ruby runtime = context.runtime;
        int columnCount = columnNames.length;

        while (resultSet.next()) {
            final IRubyObject[] row = new IRubyObject[columnCount];

            for (int i = 0; i < columnCount; i++) {
                row[i] = connection.jdbcToRuby(context, runtime, i + 1, columnTypes[i], resultSet); // Result Set is 1 based
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
        final RubyClass Result = getActiveRecordResultClass(context.runtime);
        final RubyArray rubyColumnNames = RubyArray.newArrayNoCopy(context.runtime, getColumnNames(context));
        return Result.newInstance(context, rubyColumnNames, values, columnTypeMap(context), Block.NULL_BLOCK);
    }
}
