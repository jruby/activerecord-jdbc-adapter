package arjdbc.postgresql;

import arjdbc.jdbc.JdbcResult;
import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;

import arjdbc.util.PG;
import org.jruby.*;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Block;
import org.jruby.runtime.Helpers;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import static org.jruby.api.Access.enumerableModule;
import static org.jruby.api.Access.getModule;
import static org.jruby.api.Access.objectClass;
import static org.jruby.api.Convert.toInt;
import static org.jruby.api.Error.argumentError;

/*
 * This class mimics the PG::Result class enough to get by.  It also adorns common methods useful for
 * gems like mini_sql to consume it similarly to PG::Result
 */
public class PostgreSQLResult extends JdbcResult {
    private RubyArray fields = null; // lazily created if PG fields method is called.

    // These are needed when generating an AR::Result
    private final ResultSetMetaData resultSetMetaData;

    // An optional number of updated rows
    private final long cmdTuples;

    /********* JRuby compat methods ***********/

    static RubyClass createPostgreSQLResultClass(ThreadContext context, RubyClass postgreSQLConnection) {
        RubyClass rubyClass = postgreSQLConnection.
                defineClassUnder(context, "Result", objectClass(context), ObjectAllocator.NOT_ALLOCATABLE_ALLOCATOR).
                defineMethods(context, PostgreSQLResult.class);

        rubyClass.includeModule(context, enumerableModule(context));

        return rubyClass;
    }

    /**
     * Generates a new PostgreSQLResult object for the given result set
     * @param context current thread context
     * @param clazz metaclass for this result object
     * @param resultSet the set of results that should be returned
     * @return an instantiated result object
     * @throws SQLException throws!
     */
    static PostgreSQLResult newResult(ThreadContext context,  RubyClass clazz, PostgreSQLRubyJdbcConnection connection,
                                      ResultSet resultSet) throws SQLException {
        return new PostgreSQLResult(context, clazz, connection, resultSet);
    }

    /**
     * Generates a new empty PostgreSQLResult object with a given number of updates
     * @param context current thread context
     * @param clazz metaclass for this result object
     * @param updateCount the number of updated items
     * @return an instantiated result object
     * @throws SQLException throws!
     */
    static PostgreSQLResult newEmptyResult(ThreadContext context, RubyClass clazz, PostgreSQLRubyJdbcConnection connection,
                                           long updateCount) {
        return new PostgreSQLResult(context, clazz, connection, updateCount);
    }

    /********* End JRuby compat methods ***********/

    private PostgreSQLResult(ThreadContext context, RubyClass clazz, RubyJdbcConnection connection,
                             ResultSet resultSet) throws SQLException {
        super(context, clazz, connection, resultSet);

        resultSetMetaData = resultSet.getMetaData();
        cmdTuples = -1;
    }

    private PostgreSQLResult(ThreadContext context, RubyClass clazz, RubyJdbcConnection connection,
                             long updateCount) {
        super(context, clazz, connection);

        resultSetMetaData = null;
        cmdTuples = updateCount;
    }

    /**
     * Generates a type map to be given to the AR::Result object
     * @param context current thread context
     * @return RubyHash RubyString - column name, Type::Value - type object)
     * @throws SQLException if it fails to get the field
     */
    @Override
    protected IRubyObject columnTypeMap(final ThreadContext context) throws SQLException {
        Ruby runtime = context.runtime;
        RubyHash types = RubyHash.newHash(runtime);
        int columnCount = columnNames.length;

        IRubyObject adapter = connection.adapter(context);
        for (int i = 0; i < columnCount; i++) {
            int col = i + 1;
            String typeName = resultSetMetaData.getColumnTypeName(col);

            int mod = 0;
            if  ("numeric".equals(typeName)) {
                // this field is only relevant for "numeric" type in AR
                // AR checks (fmod - 4 & 0xffff).zero?
                // pgjdbc:
                //  - for typmod == -1, getScale() and getPrecision() return 0
                //  - for typmod != -1, getScale() returns "(typmod - 4) & 0xFFFF;"
                mod = resultSetMetaData.getScale(col);
                mod = mod == 0 && resultSetMetaData.getPrecision(col) == 0 ? -1 : mod + 4;
            }

            final RubyString name = columnNames[i];
            final IRubyObject type = Helpers.invoke(context, adapter, "get_oid_type",
                    runtime.newString(typeName),
                    runtime.newFixnum(mod),
                    name);

            if (!type.isNil()) {
                types.fastASet(name, type);
                types.fastASet(runtime.newFixnum(i), type);
            }
        }

        return types;
    }

    /**
     * This is to support the Enumerable module.
     * This is needed when setting up the type maps so the Enumerable methods work
     * @param context the thread this is being executed on
     * @param block which may handle each result
     * @return this object or RubyNil
     */
    @PG @JRubyMethod
    public IRubyObject each(ThreadContext context, Block block) {
        // At this point we don't support calling this without a block
        if (block.isGiven()) {
            if (tuples == null) {
                populateTuples(context);
            }

            for (RubyHash tuple : tuples) {
                block.yield(context, tuple);
            }

            return this;
        } else {
            return context.nil;
        }
    }

    private RubyClass getBinaryDataClass(final ThreadContext context) {
        return getModule(context, "ActiveModel").
                getModule(context, "Type").
                getClass(context, "Binary").
                getClass(context, "Data");
    }

    private boolean isBinaryType(final int type) {
        return type == Types.BLOB || type == Types.BINARY || type == Types.VARBINARY || type == Types.LONGVARBINARY;
    }

    /**
     * Gives the number of rows to be returned.
     * currently defined so we match existing returned results
     * @param context current thread contect
     * @return <code>Fixnum</code>
     */
    @PG @JRubyMethod(name = {"length", "ntuples", "num_tuples"})
    public IRubyObject length(final ThreadContext context) {
        return values.length(context);
    }

    /**
     * Creates an <code>ActiveRecord::Result</code> with the data from this result.
     * Overriding the base method so we can modify binary data columns first to mark them
     * as already unencoded
     * @param context current thread context
     * @return ActiveRecord::Result object with the data from this result set
     * @throws SQLException can be caused by postgres generating its type map
     */
    @Override @SuppressWarnings("unchecked")
    public IRubyObject toARResult(final ThreadContext context) throws SQLException {
        RubyClass BinaryDataClass = null;
        int rowCount = 0;

        // This is destructive, but since this is typically the final
        // use of the rows I'm going to leave it this way unless it becomes an issue
        for (int columnIndex = 0; columnIndex < columnTypes.length; columnIndex++) {
            if (isBinaryType(columnTypes[columnIndex])) {
                // Convert the values in this column to ActiveModel::Type::Binary::Data instances
                // so AR knows it has already been unescaped
                if (BinaryDataClass == null) {
                    BinaryDataClass = getBinaryDataClass(context);
                    rowCount = values.getLength();
                }
                for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
                    RubyArray row = (RubyArray) values.eltInternal(rowIndex);
                    IRubyObject value = row.eltInternal(columnIndex);
                    if (value != context.nil) {
                        row.eltInternalSet(columnIndex, BinaryDataClass.newInstance(context, value, Block.NULL_BLOCK));
                    }
                }
            }
        }

        return super.toARResult(context);
    }

    /**
     * Returns an array of arrays of the values in the result.
     * This is defined in PG::Result and is used by some Rails tests
     * @return IRubyObject RubyArray of RubyArray of values
     */
    @PG @JRubyMethod
    public IRubyObject values() {
        return values;
    }

    /**
     * Do we have any rows of result
     * @param context the thread context
     * @return number of rows
     */
    @JRubyMethod(name = "empty?")
    public IRubyObject isEmpty(ThreadContext context) {
        return context.runtime.newBoolean(values.isEmpty());
    }

    @PG @JRubyMethod
    public RubyArray fields(ThreadContext context) {
        if (fields == null) fields = RubyArray.newArrayNoCopy(context.runtime, getColumnNames());

        return fields;
    }

    @PG @JRubyMethod(name = {"nfields", "num_fields"})
    public IRubyObject nfields(ThreadContext context) {
        return context.runtime.newFixnum(getColumnNames().length);
    }

    @PG @JRubyMethod
    public IRubyObject getvalue(ThreadContext context, IRubyObject rowArg, IRubyObject columnArg) {
        int rows = values.size();
        int row = toInt(context, rowArg);
        int column = toInt(context, columnArg);

        if (row < 0 || row >= rows) throw argumentError(context, "invalid tuple number " + row);
        if (column < 0 || column >= getColumnNames().length) throw argumentError(context, "invalid field number " + row);

        return ((RubyArray) values.eltInternal(row)).eltInternal(column);
    }

    @PG @JRubyMethod(name = "[]")
    public IRubyObject aref(ThreadContext context, IRubyObject rowArg) {
        int row = toInt(context, rowArg);
        int rows = values.size();

        if (row < 0 || row >= rows) throw argumentError(context, "Index " + row + " is out of range");

        RubyArray rowValues = (RubyArray) values.eltOk(row);
        RubyHash resultHash = RubyHash.newSmallHash(context.runtime);
        RubyArray fields = fields(context);
        int length = rowValues.getLength();
        for (int i = 0; i < length; i++) {
            resultHash.op_aset(context, fields.eltOk(i), rowValues.eltOk(i));
        }

        return resultHash;
    }

    // Note: This is probably not the best implementation,
    // but it is better than always returning 0 on non-value-returning ops.
    @PG @JRubyMethod(name = {"cmdtuples", "cmd_tuples"})
    public IRubyObject cmdtuples(ThreadContext context) {
        return cmdTuples != -1 ? context.runtime.newFixnum(cmdTuples) : values.length(context);
    }
}
