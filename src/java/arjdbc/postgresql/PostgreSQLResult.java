package arjdbc.postgresql;

import arjdbc.jdbc.JdbcResult;
import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Block;
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
    private IRubyObject adapter;
    private PgResultSetMetaData resultSetMetaData;

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
     * @param adapter a reference to the current adapter, this is needed for generating an AR::Result object
     * @return an instantiated result object
     * @throws SQLException throws!
     */
    static PostgreSQLResult newResult(ThreadContext context,  RubyClass clazz, RubyJdbcConnection connection,
                                             ResultSet resultSet, IRubyObject adapter) throws SQLException {
        return new PostgreSQLResult(context, clazz, connection, resultSet, adapter);
    }

    /********* End JRuby compat methods ***********/

    private PostgreSQLResult(ThreadContext context, RubyClass clazz, RubyJdbcConnection connection,
                             ResultSet resultSet, final IRubyObject adapter) throws SQLException {
        super(context, clazz, connection, resultSet);

        this.adapter = adapter;
        resultSetMetaData = (PgResultSetMetaData) resultSet.getMetaData();
    }

    /**
     * Generates a type map to be given to the AR::Result object
     * @param context current thread context
     * @return RubyHash RubyString - column name, Type::Value - type object)
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
     * Returns an array of arrays of the values in the result.
     * This is defined in PG::Result and is used by some Rails tests
     * @return IRubyObject RubyArray of RubyArray of values
     */
    @JRubyMethod
    public IRubyObject values() {
        return values;
    }
}
