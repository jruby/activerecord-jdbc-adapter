package arjdbc.postgresql;

import arjdbc.jdbc.JdbcResult;
import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;

import arjdbc.util.PG;
import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyModule;
import org.jruby.RubyNumeric;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Block;
import org.jruby.runtime.Helpers;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/*
 * This class mimics the PG::Result class enough to get by.  It also adorns common methods useful for
 * gems like mini_sql to consume it similarly to PG::Result
 */
public class PostgreSQLResult extends JdbcResult {
    private RubyArray fields = null; // lazily created if PG fields method is called.

    // These are needed when generating an AR::Result
    private final ResultSetMetaData resultSetMetaData;

    /********* JRuby compat methods ***********/

    static RubyClass createPostgreSQLResultClass(Ruby runtime, RubyClass postgreSQLConnection) {
        RubyClass rubyClass = postgreSQLConnection.defineClassUnder("Result", runtime.getObject(), ObjectAllocator.NOT_ALLOCATABLE_ALLOCATOR);
        rubyClass.defineAnnotatedMethods(PostgreSQLResult.class);
        rubyClass.includeModule(runtime.getEnumerable());
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

    /********* End JRuby compat methods ***********/

    private PostgreSQLResult(ThreadContext context, RubyClass clazz, RubyJdbcConnection connection,
                             ResultSet resultSet) throws SQLException {
        super(context, clazz, connection, resultSet);

        resultSetMetaData = resultSet.getMetaData();
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

            if (!type.isNil()) types.fastASet(name, type);
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
        return ((RubyModule) context.runtime.getModule("ActiveModel").getConstantAt("Type")).getClass("Binary").getClass("Data");
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
        return values.length();
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
        int row = RubyNumeric.fix2int(rowArg);
        int column = RubyNumeric.fix2int(columnArg);

        if (row < 0 || row >= rows) throw context.runtime.newArgumentError("invalid tuple number " + row);
        if (column < 0 || column >= getColumnNames().length) throw context.runtime.newArgumentError("invalid field number " + row);

        return ((RubyArray) values.eltInternal(row)).eltInternal(column);
    }

    @PG @JRubyMethod(name = "[]")
    public IRubyObject aref(ThreadContext context, IRubyObject rowArg) {
        int row = RubyNumeric.fix2int(rowArg);
        int rows = values.size();

        if (row < 0 || row >= rows) throw context.runtime.newArgumentError("Index " + row + " is out of range");

        RubyArray rowValues = (RubyArray) values.eltOk(row);
        RubyHash resultHash = RubyHash.newSmallHash(context.runtime);
        RubyArray fields = fields(context);
        int length = rowValues.getLength();
        for (int i = 0; i < length; i++) {
            resultHash.op_aset(context, fields.eltOk(i), rowValues.eltOk(i));
        }

        return resultHash;
    }

    // Note: this is # of commands (insert/update/selects performed) and not number of rows.  In practice,
    // so far users always just check this as to when it is 0 which ends up being the same as an update/insert
    // where no rows were affected...so wrong value but the important value will be the same (I do not see
    // how jdbc can do this).
    @PG @JRubyMethod(name = {"cmdtuples", "cmd_tuples"})
    public IRubyObject cmdtuples(ThreadContext context) {
        return values.isEmpty() ? context.runtime.newFixnum(0) : aref(context, context.runtime.newFixnum(0));
    }
}
