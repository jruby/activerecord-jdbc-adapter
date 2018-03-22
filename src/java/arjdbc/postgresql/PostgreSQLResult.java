package arjdbc.postgresql;

import arjdbc.jdbc.JdbcResult;
import arjdbc.jdbc.types.AbstractType;
import arjdbc.jdbc.types.StringWithDefaultEncodingType;
import arjdbc.postgresql.types.BitStringType;
import arjdbc.postgresql.types.ObjectType;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;

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
        RubyHash types = RubyHash.newHash(context.runtime);
        PgResultSetMetaDataWrapper mdWrapper = new PgResultSetMetaDataWrapper(resultSetMetaData);

        for (int i = 0; i < columns.length; i++) {
            final Field field = mdWrapper.getField(i + 1);
            final RubyString name = columns[i].getName(context);

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
     * Creates a type object for the given column type
     * @param name the name of the column
     * @param columnType the type identifier for the column
     * @param index the index for this column in the row
     * @return an intialized type object
     */
    @Override
    protected AbstractType getColumnType(String name, int columnType, int index) {
        switch (columnType) {
            case Types.BIT:
                return new BitStringType(name, index);
            case Types.OTHER:
                return new ObjectType(name, index);
            case Types.CHAR:
            case Types.VARCHAR:
            case Types.NCHAR:
            case Types.NVARCHAR:
            case Types.CLOB:
            case Types.NCLOB:
            case Types.LONGVARCHAR:
            case Types.LONGNVARCHAR:
                return new StringWithDefaultEncodingType(name, index);
        }

        return super.getColumnType(name, columnType, index);
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
