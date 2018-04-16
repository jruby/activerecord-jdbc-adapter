package arjdbc.postgresql;

import arjdbc.jdbc.JdbcResult;
import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyMethod;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Block;
import org.jruby.runtime.Helpers;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.postgresql.core.Field;
import org.postgresql.jdbc.PgResultSetMetaData;
import org.postgresql.jdbc.PgResultSetMetaDataWrapper; // This is a hack unfortunately to get around method scoping

/*
 * This class mimics the PG:Result class enough to get by
 */
public class PostgreSQLResult extends JdbcResult {

    // These are needed when generating an AR::Result
    private final PgResultSetMetaData resultSetMetaData;

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

        resultSetMetaData = (PgResultSetMetaData) resultSet.getMetaData();
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
        PgResultSetMetaDataWrapper mdWrapper = new PgResultSetMetaDataWrapper(resultSetMetaData);
        int columnCount = columnNames.length;

        IRubyObject adapter = connection.adapter(context);
        for (int i = 0; i < columnCount; i++) {
            final Field field = mdWrapper.getField(i + 1);
            final RubyString name = columnNames[i];
            final IRubyObject type = Helpers.invoke(context, adapter, "get_oid_type",
                    runtime.newFixnum(field.getOID()),
                    runtime.newFixnum(field.getMod()),
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
    @JRubyMethod
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
    @JRubyMethod
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
    @Override
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
                        row.eltInternalSet(columnIndex, (IRubyObject) BinaryDataClass.newInstance(context, value, Block.NULL_BLOCK));
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
    @JRubyMethod
    public IRubyObject values() {
        return values;
    }
}
