/*
 **** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2006-2011 Nick Sieger <nick@nicksieger.com>
 * Copyright (c) 2006-2007 Ola Bini <ola.bini@gmail.com>
 * Copyright (c) 2008-2009 Thomas E Enebo <enebo@acm.org>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 ***** END LICENSE BLOCK *****/
package arjdbc.jdbc;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.Reader;
import java.io.StringReader;
import java.math.BigInteger;
import java.sql.Array;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.SQLXML;
import java.sql.Statement;
import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;
import java.sql.Types;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collection;
import java.util.List;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBignum;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyInteger;
import org.jruby.RubyModule;
import org.jruby.RubyNumeric;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.RubySymbol;
import org.jruby.RubyTime;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.javasupport.JavaUtil;
import org.jruby.javasupport.util.RuntimeHelpers;
import org.jruby.runtime.Arity;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 * Part of our ActiveRecord::ConnectionAdapters::Connection impl.
 */
public class RubyJdbcConnection extends RubyObject {
    
    private static final String[] TABLE_TYPE = new String[] { "TABLE" };
    private static final String[] TABLE_TYPES = new String[] { "TABLE", "VIEW", "SYNONYM" };

    protected RubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    private static ObjectAllocator JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new RubyJdbcConnection(runtime, klass);
        }
    };
    
    public static RubyClass createJdbcConnectionClass(final Ruby runtime) {
        RubyClass jdbcConnection = getConnectionAdapters(runtime).
            defineClassUnder("JdbcConnection", runtime.getObject(), JDBCCONNECTION_ALLOCATOR);
        jdbcConnection.defineAnnotatedMethods(RubyJdbcConnection.class);
        return jdbcConnection;
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::ConnectionAdapters</code>
     */
    protected static RubyModule getConnectionAdapters(final Ruby runtime) {
        return (RubyModule) runtime.fastGetModule("ActiveRecord").fastGetConstant("ConnectionAdapters");
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::Result</code>
     */
    protected static RubyClass getResult(final Ruby runtime) {
        return runtime.fastGetModule("ActiveRecord").fastGetClass("Result");
    }
    
    /**
     * @param runtime
     * @return <code>ActiveRecord::ConnectionAdapters::IndexDefinition</code>
     */
    protected static RubyClass getIndexDefinition(final Ruby runtime) {
        return getConnectionAdapters(runtime).fastGetClass("IndexDefinition");
    }
    
    /**
     * @param runtime
     * @return <code>ActiveRecord::TransactionIsolationError</code>
     */
    protected static RubyClass getJDBCError(final Ruby runtime) {
        return runtime.fastGetModule("ActiveRecord").fastGetClass("JDBCError");
    }

    /**
     * NOTE: Only available since AR-4.0
     * @param runtime
     * @return <code>ActiveRecord::TransactionIsolationError</code>
     */
    protected static RubyClass getTransactionIsolationError(final Ruby runtime) {
        return (RubyClass) runtime.fastGetModule("ActiveRecord").fastGetConstant("TransactionIsolationError");
    }
    
    /**
     * @param runtime
     * @return <code>ActiveRecord::ConnectionAdapters::JdbcTypeConverter</code>
     */
    private static RubyClass getJdbcTypeConverter(final Ruby runtime) {
        return getConnectionAdapters(runtime).fastGetClass("JdbcTypeConverter");
    }
    
    /*
      def transaction_isolation_levels
        {
          read_uncommitted: "READ UNCOMMITTED",
          read_committed:   "READ COMMITTED",
          repeatable_read:  "REPEATABLE READ",
          serializable:     "SERIALIZABLE"
        }
      end 
    */

    public static int mapTransactionIsolationLevel(IRubyObject isolation) {
        if ( ! ( isolation instanceof RubySymbol ) ) {
            isolation = isolation.convertToString().callMethod("intern");
        }
        
        final Object isolationString = isolation.toString(); // RubySymbol.toString
        if ( isolationString == "read_uncommitted" ) return Connection.TRANSACTION_READ_UNCOMMITTED; // 1
        if ( isolationString == "read_committed" ) return Connection.TRANSACTION_READ_COMMITTED; // 2
        if ( isolationString == "repeatable_read" ) return Connection.TRANSACTION_REPEATABLE_READ; // 4
        if ( isolationString == "serializable" ) return Connection.TRANSACTION_SERIALIZABLE; // 8
        
        throw new IllegalArgumentException(
                "unexpected isolation level: " + isolation + " (" + isolationString + ")"
        );
    }

    @JRubyMethod(name = "supports_transaction_isolation?", optional = 1)
    public IRubyObject supports_transaction_isolation_p(final ThreadContext context, 
        final IRubyObject[] args) throws SQLException {
        final IRubyObject isolation = args.length > 0 ? args[0] : null;
        
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final DatabaseMetaData metaData = connection.getMetaData();
                final boolean supported;
                if ( isolation != null && ! isolation.isNil() ) {
                    final int level = mapTransactionIsolationLevel(isolation);
                    supported = metaData.supportsTransactionIsolationLevel(level);
                }
                else {
                    final int level = metaData.getDefaultTransactionIsolation();
                    supported = level > Connection.TRANSACTION_NONE; // > 0
                }
                return context.getRuntime().newBoolean(supported);
            }
        });
    }
    
    @JRubyMethod(name = "begin", optional = 1) // optional isolation argument for AR-4.0
    public IRubyObject begin(final ThreadContext context, final IRubyObject[] args) {
        final IRubyObject isolation = args.length > 0 ? args[0] : null;
        try { // handleException == false so we can handle setTXIsolation
            return withConnection(context, false, new Callable<IRubyObject>() {
                public IRubyObject call(final Connection connection) throws SQLException {
                    connection.setAutoCommit(false);
                    if ( isolation != null && ! isolation.isNil() ) {
                        final int level = mapTransactionIsolationLevel(isolation);
                        try {
                            connection.setTransactionIsolation(level);
                        } 
                        catch (SQLException e) {
                            RubyClass txError = getTransactionIsolationError(context.getRuntime());
                            if ( txError != null ) throw wrapException(context, txError, e);
                            throw e; // let it roll - will be wrapped into a JDBCError (non 4.0)
                        }
                    }
                    return context.getRuntime().getNil();
                }
            });
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }
    
    @JRubyMethod(name = "commit")
    public IRubyObject commit(final ThreadContext context) {
        final Connection connection = getConnection(true);
        try {
            if ( ! connection.getAutoCommit() ) {
                try {
                    connection.commit();
                    return context.getRuntime().newBoolean(true);
                }
                finally {
                    connection.setAutoCommit(true);
                }
            }
            return context.getRuntime().getNil();
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @JRubyMethod(name = "rollback")
    public IRubyObject rollback(final ThreadContext context) {
        final Connection connection = getConnection(true);
        try {
            if ( ! connection.getAutoCommit() ) {
                try {
                    connection.rollback();
                    return context.getRuntime().newBoolean(true);
                } finally {
                    connection.setAutoCommit(true);
                }
            }
            return context.getRuntime().getNil();
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }
    
    @JRubyMethod(name = "connection")
    public IRubyObject connection(final ThreadContext context) {
        if ( getConnection(false) == null ) { 
            synchronized (this) {
                if ( getConnection(false) == null ) {
                    reconnect(context);
                }
            }
        }
        return getInstanceVariable("@connection");
    }

    @JRubyMethod(name = "disconnect!")
    public IRubyObject disconnect(final ThreadContext context) {
        // TODO: only here to try resolving multi-thread issues :
        // https://github.com/jruby/activerecord-jdbc-adapter/issues/197
        // https://github.com/jruby/activerecord-jdbc-adapter/issues/198
        if ( Boolean.getBoolean("arjdbc.disconnect.debug") ) {
            final Ruby runtime = context.getRuntime();
            List backtrace = (List) context.createCallerBacktrace(runtime, 0);
            runtime.getOut().println(this + " connection.disconnect! occured: ");
            for ( Object element : backtrace ) { 
                runtime.getOut().println(element);
            }
            runtime.getOut().flush();
        }
        return setConnection(null);
    }

    @JRubyMethod(name = "reconnect!")
    public IRubyObject reconnect(final ThreadContext context) {
        try {
            return setConnection( getConnectionFactory().newConnection() );
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }
    
    @JRubyMethod(name = "database_name")
    public IRubyObject database_name(ThreadContext context) throws SQLException {
        Connection connection = getConnection(true);
        String name = connection.getCatalog();

        if (null == name) {
            name = connection.getMetaData().getUserName();

            if (null == name) name = "db1";
        }

        return context.getRuntime().newString(name);
    }

    @JRubyMethod(name = "execute", required = 1)
    public IRubyObject execute(final ThreadContext context, final IRubyObject sql) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null;
                final String query = sql.convertToString().getUnicodeValue();
                try {
                    statement = connection.createStatement();
                    if (genericExecute(statement, query)) {
                        return unmarshalResults(context, connection.getMetaData(), statement, false);
                    } else {
                        return unmarshalKeysOrUpdateCount(context, connection, statement);
                    }
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                }
                finally { close(statement); }
            }
        });
    }

    protected boolean genericExecute(Statement stmt, String query) throws SQLException {
        return stmt.execute(query);
    }
    
    protected IRubyObject unmarshalKeysOrUpdateCount(
            final ThreadContext context, final Connection connection, final Statement statement) throws SQLException {
        final Ruby runtime = context.getRuntime();
        final IRubyObject key;
        if ( connection.getMetaData().supportsGetGeneratedKeys() ) {
            key = unmarshalIdResult(runtime, statement);
        }
        else {
            key = runtime.getNil();
        }
        return key.isNil() ? runtime.newFixnum( statement.getUpdateCount() ) : key;
     }

    @JRubyMethod(name = "execute_id_insert", required = 2)
    public IRubyObject execute_id_insert(final ThreadContext context, 
        final IRubyObject sql, final IRubyObject id) throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                PreparedStatement statement = null;
                final String insertSQL = sql.convertToString().getUnicodeValue();
                try {
                    statement = connection.prepareStatement(insertSQL);
                    statement.setLong(1, RubyNumeric.fix2long(id));
                    statement.executeUpdate();
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, insertSQL);
                    throw e;
                }
                finally { close(statement); }
                return id;
            }
        });
    }

    @JRubyMethod(name = "execute_insert", required = 1)
    public IRubyObject execute_insert(final ThreadContext context, final IRubyObject sql)
        throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null;
                final String insertSQL = sql.convertToString().getUnicodeValue();
                try {
                    statement = connection.createStatement();
                    statement.executeUpdate(insertSQL, Statement.RETURN_GENERATED_KEYS);
                    return unmarshal_id_result(context.getRuntime(), statement.getGeneratedKeys());
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, insertSQL);
                    throw e;
                }
                finally { close(statement); }
            }
        });
    }

    @JRubyMethod(name = "execute_query", required = 1)
    public IRubyObject execute_query(final ThreadContext context, IRubyObject sql)
        throws SQLException {
        String query = sql.convertToString().getUnicodeValue();
        return executeQuery(context, query, 0);
    }

    @JRubyMethod(name = "execute_query", required = 2)
    public IRubyObject execute_query(final ThreadContext context, 
        final IRubyObject sql, final IRubyObject maxRows) throws SQLException {
        final String query = sql.convertToString().getUnicodeValue();
        return executeQuery(context, query, RubyNumeric.fix2int(maxRows));
    }

    protected IRubyObject executeQuery(final ThreadContext context, final String query, final int maxRows) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final Ruby runtime = context.getRuntime();
                Statement statement = null;
                try {
                    final DatabaseMetaData metaData = connection.getMetaData();
                    statement = connection.createStatement();
                    statement.setMaxRows(maxRows);
                    return unmarshalResult(context, runtime, metaData, statement.executeQuery(query), false);
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                }
                finally { close(statement); }
            }
        });
    }
    
    @JRubyMethod(name = {"execute_update", "execute_delete"}, required = 1)
    public IRubyObject execute_update(final ThreadContext context, final IRubyObject sql)
        throws SQLException {
        return withConnection(context, new Callable<RubyInteger>() {
            public RubyInteger call(final Connection connection) throws SQLException {
                Statement statement = null;
                final String updateSQL = sql.convertToString().getUnicodeValue();
                try {
                    statement = connection.createStatement();
                    return context.getRuntime().newFixnum(statement.executeUpdate(updateSQL));
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, updateSQL);
                    throw e;
                }
                finally { close(statement); }
            }
        });
    }

    @JRubyMethod(name = "native_database_types", frame = false)
    public IRubyObject native_database_types() {
        return getInstanceVariable("@native_database_types");
    }


    @JRubyMethod(name = "primary_keys", required = 1)
    public IRubyObject primary_keys(ThreadContext context, IRubyObject tableName) throws SQLException {
        @SuppressWarnings("unchecked")
        List<IRubyObject> primaryKeys = (List) primaryKeys(context, tableName.toString());
        return context.getRuntime().newArray(primaryKeys);
    }

    private static final int PRIMARY_KEYS_COLUMN_NAME = 4;
    
    protected List<RubyString> primaryKeys(final ThreadContext context, final String tableName) {
        return withConnection(context, new Callable<List<RubyString>>() {
            public List<RubyString> call(final Connection connection) throws SQLException {
                final Ruby runtime = context.getRuntime();
                final DatabaseMetaData metaData = connection.getMetaData();
                final String _tableName = caseConvertIdentifierForJdbc(metaData, tableName);
                ResultSet resultSet = null;
                final List<RubyString> keyNames = new ArrayList<RubyString>();
                try {
                    TableName components = extractTableName(connection, null, _tableName);
                    resultSet = metaData.getPrimaryKeys(components.catalog, components.schema, components.name);

                    while (resultSet.next()) {
                        String columnName = resultSet.getString(PRIMARY_KEYS_COLUMN_NAME);
                        columnName = caseConvertIdentifierForRails(metaData, columnName);
                        keyNames.add( RubyString.newUnicodeString(runtime, columnName) );
                    }
                }
                finally { close(resultSet); }
                return keyNames;
            }
        });
    }
    
    @JRubyMethod(name = "set_native_database_types")
    public IRubyObject set_native_database_types(final ThreadContext context) 
        throws SQLException { // TODO we should handle exceptions !
        final Ruby runtime = context.getRuntime();
        final DatabaseMetaData metaData = getConnection(true).getMetaData();
        IRubyObject types = unmarshalResult(context, runtime, metaData, metaData.getTypeInfo(), true);
        
        IRubyObject typeConverter = getJdbcTypeConverter(runtime).callMethod("new", types);
        setInstanceVariable("@native_types", typeConverter.callMethod(context, "choose_best_types"));

        return runtime.getNil();
    }

    @JRubyMethod(name = "tables")
    public IRubyObject tables(ThreadContext context) {
        return tables(context, null, null, null, TABLE_TYPE);
    }

    @JRubyMethod(name = "tables")
    public IRubyObject tables(ThreadContext context, IRubyObject catalog) {
        return tables(context, toStringOrNull(catalog), null, null, TABLE_TYPE);
    }

    @JRubyMethod(name = "tables")
    public IRubyObject tables(ThreadContext context, IRubyObject catalog, IRubyObject schemaPattern) {
        return tables(context, toStringOrNull(catalog), toStringOrNull(schemaPattern), null, TABLE_TYPE);
    }

    @JRubyMethod(name = "tables")
    public IRubyObject tables(ThreadContext context, IRubyObject catalog, IRubyObject schemaPattern, IRubyObject tablePattern) {
        return tables(context, toStringOrNull(catalog), toStringOrNull(schemaPattern), toStringOrNull(tablePattern), TABLE_TYPE);
    }

    @JRubyMethod(name = "tables", required = 4, rest = true)
    public IRubyObject tables(ThreadContext context, IRubyObject[] args) {
        return tables(context, toStringOrNull(args[0]), toStringOrNull(args[1]), toStringOrNull(args[2]), getTypes(args[3]));
    }

    protected IRubyObject tables(ThreadContext context, String catalog, String schemaPattern, String tablePattern, String[] types) {
        return withConnection(context, tableLookupBlock(context.getRuntime(), catalog, schemaPattern, tablePattern, types));
    }

    protected String[] getTableTypes() {
        return TABLE_TYPES;
    }

    @JRubyMethod(name = "table_exists?", required = 1, optional = 1)
    public IRubyObject table_exists_p(final ThreadContext context, final IRubyObject[] args) {
        IRubyObject name = args[0], schema_name = args.length > 1 ? args[1] : null;
        if ( ! ( name instanceof RubyString ) ) {
            name = name.callMethod(context, "to_s");
        }
        final String tableName = ((RubyString) name).getUnicodeValue();
        final String tableSchema = schema_name == null ? null : schema_name.convertToString().getUnicodeValue();
        final Ruby runtime = context.getRuntime();
        
        return withConnection(context, new Callable<RubyBoolean>() {
            public RubyBoolean call(final Connection connection) throws SQLException {
                final TableName components = extractTableName(connection, tableSchema, tableName);
                
                final Collection matchingTables = tableLookupBlock(
                    runtime, components.catalog, components.schema, components.name, getTableTypes()
                ).call(connection);
                
                return runtime.newBoolean( ! matchingTables.isEmpty() );
            }
        });
    }
    
    @JRubyMethod(name = {"columns", "columns_internal"}, required = 1, optional = 2)
    public IRubyObject columns_internal(final ThreadContext context, final IRubyObject[] args)
        throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                ResultSet columns = null, primaryKeys = null;
                try {
                    final String tableName = args[0].convertToString().getUnicodeValue();
                    // optionals (NOTE: catalog argumnet was never used before 1.3.0) :
                    final String catalog = args.length > 1 ? toStringOrNull(args[1]) : null;
                    final String defaultSchema = args.length > 2 ? toStringOrNull(args[2]) : null;
                    
                    final TableName components;
                    if ( catalog == null ) { // backwards-compatibility with < 1.3.0
                        components = extractTableName(connection, defaultSchema, tableName);
                    }
                    else {
                        components = extractTableName(connection, catalog, defaultSchema, tableName);
                    }

                    final Collection matchingTables = tableLookupBlock(context.getRuntime(),
                        components.catalog, components.schema, components.name, getTableTypes()
                    ).call(connection);
                    if ( matchingTables.isEmpty() ) {
                        throw new SQLException("table: " + tableName + " does not exist");
                    }

                    final DatabaseMetaData metaData = connection.getMetaData();
                    columns = metaData.getColumns(components.catalog, components.schema, components.name, null);
                    primaryKeys = metaData.getPrimaryKeys(components.catalog, components.schema, components.name);
                    return unmarshalColumns(context, metaData, columns, primaryKeys);
                }
                finally {
                    close(columns);
                    close(primaryKeys);
                }
            }
        });
    }
    
    @JRubyMethod(name = "indexes")
    public IRubyObject indexes(ThreadContext context, IRubyObject tableName, IRubyObject name, IRubyObject schemaName) {
        return indexes(context, toStringOrNull(tableName), toStringOrNull(name), toStringOrNull(schemaName));
    }

    // NOTE: metaData.getIndexInfo row mappings :
    private static final int INDEX_INFO_TABLE_NAME = 3;
    private static final int INDEX_INFO_NON_UNIQUE = 4;
    private static final int INDEX_INFO_NAME = 6;
    private static final int INDEX_INFO_COLUMN_NAME = 9;

    /**
     * Default JDBC introspection for index metadata on the JdbcConnection.
     *
     * JDBC index metadata is denormalized (multiple rows may be returned for
     * one index, one row per column in the index), so a simple block-based
     * filter like that used for tables doesn't really work here.  Callers
     * should filter the return from this method instead.
     */
    protected IRubyObject indexes(final ThreadContext context, final String tableName, final String name, final String schemaName) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final Ruby runtime = context.getRuntime();
                final RubyClass indexDefinition = getIndexDefinition(runtime);
                
                final DatabaseMetaData metaData = connection.getMetaData();
                String _tableName = caseConvertIdentifierForJdbc(metaData, tableName);
                String _schemaName = caseConvertIdentifierForJdbc(metaData, schemaName);
                
                final List<RubyString> primaryKeys = primaryKeys(context, _tableName);
                ResultSet indexInfoSet = null;
                final List<IRubyObject> indexes = new ArrayList<IRubyObject>();
                try {
                    indexInfoSet = metaData.getIndexInfo(null, _schemaName, _tableName, false, true);
                    String currentIndex = null;

                    while ( indexInfoSet.next() ) {
                        String indexName = indexInfoSet.getString(INDEX_INFO_NAME);
                        if ( indexName == null ) continue;
                        indexName = caseConvertIdentifierForRails(metaData, indexName);

                        final String columnName = indexInfoSet.getString(INDEX_INFO_COLUMN_NAME);
                        final RubyString rubyColumnName = RubyString.newUnicodeString(
                                runtime, caseConvertIdentifierForRails(metaData, columnName)
                        );
                        if ( primaryKeys.contains(rubyColumnName) ) continue;

                        // We are working on a new index
                        if ( ! indexName.equals(currentIndex) ) {
                            currentIndex = indexName;

                            String indexTableName = indexInfoSet.getString(INDEX_INFO_TABLE_NAME);
                            indexTableName = caseConvertIdentifierForRails(metaData, indexTableName);
                            
                            final boolean nonUnique = indexInfoSet.getBoolean(INDEX_INFO_NON_UNIQUE);
                            
                            IRubyObject[] args = new IRubyObject[] {
                                RubyString.newUnicodeString(runtime, indexTableName), // table_name
                                RubyString.newUnicodeString(runtime, indexName), // index_name
                                runtime.newBoolean( ! nonUnique ), // unique
                                runtime.newArray() // [] for column names, we'll add to that in just a bit
                            };

                            indexes.add( indexDefinition.callMethod(context, "new", args) ); // IndexDefinition.new
                        }

                        // One or more columns can be associated with an index
                        IRubyObject lastIndexDef = indexes.isEmpty() ? null : indexes.get(indexes.size() - 1);
                        if (lastIndexDef != null) {
                            lastIndexDef.callMethod(context, "columns").callMethod(context, "<<", rubyColumnName);
                        }
                    }

                    return runtime.newArray(indexes);
                    
                } finally { close(indexInfoSet); }
            }
        });
    }
    
    // NOTE: this seems to be not used ... at all, deprecate ?
    /*
     * sql, values, types, name = nil, pk = nil, id_value = nil, sequence_name = nil
     */
    @JRubyMethod(name = "insert_bind", required = 3, rest = true)
    public IRubyObject insert_bind(final ThreadContext context, final IRubyObject[] args) throws SQLException {
        final Ruby runtime = context.getRuntime();
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final String sql = args[0].convertToString().toString();
                PreparedStatement statement = null;
                try {
                    statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
                    setValues(context, args[1], args[2], statement);
                    statement.executeUpdate();
                    return unmarshalIdResult(runtime, statement);
                }
                finally { close(statement); }
            }
        });
    }
    
    // NOTE: this seems to be not used ... at all, deprecate ?
    /*
     * sql, values, types, name = nil
     */
    @Deprecated
    @JRubyMethod(name = "update_bind", required = 3, rest = true)
    public IRubyObject update_bind(final ThreadContext context, final IRubyObject[] args) throws SQLException {
        final Ruby runtime = context.getRuntime();
        Arity.checkArgumentCount(runtime, args, 3, 4);
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final String sql = args[0].convertToString().toString();
                PreparedStatement statement = null;
                try {
                    statement = connection.prepareStatement(sql);
                    setValues(context, args[1], args[2], statement);
                    statement.executeUpdate();
                }
                finally { close(statement); }
                return runtime.getNil();
            }
        });
    }

    @JRubyMethod(name = "with_connection_retry_guard", frame = true)
    public IRubyObject with_connection_retry_guard(final ThreadContext context, final Block block) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                return block.call(context, new IRubyObject[] { convertJavaToRuby(connection) });
            }
        });
    }

    /*
     * (is binary?, colname, tablename, primary_key, id, lob_value)
     */
    @JRubyMethod(name = "write_large_object", required = 6)
    public IRubyObject write_large_object(final ThreadContext context, final IRubyObject[] args)
        throws SQLException {
        
        final boolean isBinary = args[0].isTrue(); 
        final RubyString columnName = args[1].convertToString();
        final RubyString tableName = args[2].convertToString();
        final RubyString idKey = args[3].convertToString();
        final RubyString idVal = args[4].convertToString();
        final IRubyObject lobValue = args[5];
        
        final Ruby runtime = context.getRuntime();
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final String sql = "UPDATE "+ tableName +
                    " SET "+ columnName +" = ? WHERE "+ idKey +" = "+ idVal;
                PreparedStatement statement = null;
                try {
                    statement = connection.prepareStatement(sql);
                    if ( isBinary ) { // binary
                        ByteList blob = lobValue.convertToString().getByteList();
                        statement.setBinaryStream(1, 
                            new ByteArrayInputStream(blob.bytes, blob.begin, blob.realSize), blob.realSize
                        );
                    } else { // clob
                        String clob = lobValue.convertToString().getUnicodeValue();
                        statement.setCharacterStream(1, new StringReader(clob), clob.length());
                    }
                    statement.executeUpdate();
                }
                finally { close(statement); }
                return runtime.getNil();
            }
        });
    }

    /**
     * Convert an identifier coming back from the database to a case which Rails is expecting.
     *
     * Assumption: Rails identifiers will be quoted for mixed or will stay mixed
     * as identifier names in Rails itself.  Otherwise, they expect identifiers to
     * be lower-case.  Databases which store identifiers uppercase should be made
     * lower-case.
     *
     * Assumption 2: It is always safe to convert all upper case names since it appears that
     * some adapters do not report StoresUpper/Lower/Mixed correctly (am I right postgres/mysql?).
     */
    protected static String caseConvertIdentifierForRails(final DatabaseMetaData metaData, final String value)
        throws SQLException {
        if ( value == null ) return null;
        
        return metaData.storesUpperCaseIdentifiers() ? value.toLowerCase() : value;
    }

    /**
     * Convert an identifier destined for a method which cares about the databases internal
     * storage case.  Methods like DatabaseMetaData.getPrimaryKeys() needs the table name to match
     * the internal storage name.  Arbtrary queries and the like DO NOT need to do this.
     */
    protected String caseConvertIdentifierForJdbc(final DatabaseMetaData metaData, final String value)
        throws SQLException {
        if ( value == null ) return null;
        
        if ( metaData.storesUpperCaseIdentifiers() ) {
            return value.toUpperCase();
        }
        else if ( metaData.storesLowerCaseIdentifiers() ) {
            return value.toLowerCase();
        }

        return value;
    }

    protected IRubyObject getConfigValue(final ThreadContext context, final String key) {
        final IRubyObject config = getInstanceVariable("@config");
        return config.callMethod(context, "[]", context.getRuntime().newSymbol(key));
    }
    
    /**
     * @deprecated renamed to {@link #getConfigValue(ThreadContext, String)}
     */
    @Deprecated
    protected IRubyObject config_value(ThreadContext context, String key) {
        return getConfigValue(context, key);
    }

    private static String toStringOrNull(IRubyObject arg) {
        return arg.isNil() ? null : arg.toString();
    }

    protected IRubyObject getAdapter(ThreadContext context) {
        return callMethod(context, "adapter");
    }

    protected IRubyObject getJdbcColumnClass(ThreadContext context) {
        return getAdapter(context).callMethod(context, "jdbc_column_class");
    }

    protected JdbcConnectionFactory getConnectionFactory() throws RaiseException {
        IRubyObject connection_factory = getInstanceVariable("@connection_factory");
        if (connection_factory == null) {
            throw getRuntime().newRuntimeError("@connection_factory not set");
        }
        JdbcConnectionFactory connectionFactory;
        try {
            connectionFactory = (JdbcConnectionFactory) 
                connection_factory.toJava(JdbcConnectionFactory.class);
        }
        catch (Exception e) { // TODO debug this !
            connectionFactory = null;
        }
        if (connectionFactory == null) {
            throw getRuntime().newRuntimeError("@connection_factory not set properly");
        }
        return connectionFactory;
    }

    private static String[] getTypes(final IRubyObject typeArg) {
        if ( typeArg instanceof RubyArray ) {
            IRubyObject[] rubyTypes = ((RubyArray) typeArg).toJavaArray();
            
            final String[] types = new String[rubyTypes.length];
            for ( int i = 0; i < types.length; i++ ) {
                types[i] = rubyTypes[i].toString();
            }
            return types;
        }
        return new String[] { typeArg.toString() }; // expect a RubyString
    }
    
    private static int jdbcTypeFor(final ThreadContext context, IRubyObject type) 
        throws SQLException {
        if ( ! ( type instanceof RubySymbol ) ) {
            if ( type instanceof RubyString ) { // to_sym
                if ( context.getRuntime().is1_9() ) {
                    type = ( (RubyString) type ).intern19();
                }
                else {
                    type = ( (RubyString) type ).intern();
                }
            }
            else {
                throw new IllegalArgumentException(
                    "expected a Ruby string/symbol but got: " + type + " (" + type.getMetaClass().getName() + ")"
                );
            }
        }
        
        final String internedValue = type.asJavaString();

        if ( internedValue == (Object) "string" ) return Types.VARCHAR;
        else if ( internedValue == (Object) "text" ) return Types.CLOB;
        else if ( internedValue == (Object) "integer" ) return Types.INTEGER;
        else if ( internedValue == (Object) "decimal" ) return Types.DECIMAL;
        else if ( internedValue == (Object) "float" ) return Types.FLOAT;
        else if ( internedValue == (Object) "datetime") return Types.TIMESTAMP;
        else if ( internedValue == (Object) "timestamp" ) return Types.TIMESTAMP;
        else if ( internedValue == (Object) "time" ) return Types.TIME;
        else if ( internedValue == (Object) "date" ) return Types.DATE;
        else if ( internedValue == (Object) "binary" ) return Types.BLOB;
        else if ( internedValue == (Object) "boolean" ) return Types.BOOLEAN;
        else if ( internedValue == (Object) "xml" ) return Types.SQLXML;
        else if ( internedValue == (Object) "array" ) return Types.ARRAY;
        else return -1;
    }

    protected void populateFromResultSet(
            final ThreadContext context, final Ruby runtime, 
            final List<IRubyObject> results, final ResultSet resultSet, 
            final ColumnData[] columns) throws SQLException {
        final int columnCount = columns.length;
        
        while ( resultSet.next() ) {
            RubyHash row = RubyHash.newHash(runtime);

            for ( int i = 0; i < columnCount; i++ ) {
                final ColumnData column = columns[i];
                row.op_aset(context, column.name, jdbcToRuby(runtime, column.index, column.type, resultSet));
            }

            results.add(row);
        }
    }
    
    protected IRubyObject jdbcToRuby(final Ruby runtime, final int column, 
        final int type, final ResultSet resultSet) throws SQLException {
        try {
            switch (type) {
            case Types.BLOB:
            case Types.BINARY:
            case Types.VARBINARY:
            case Types.LONGVARBINARY:
                InputStream stream = resultSet.getBinaryStream(column);
                try {
                    return streamToRuby(runtime, resultSet, stream);
                }
                finally { if ( stream != null ) stream.close(); }
            case Types.CLOB:
            case Types.NCLOB: // JDBC 4.0
                Reader reader = resultSet.getCharacterStream(column);
                try {
                    return readerToRuby(runtime, resultSet, reader);
                }
                finally { if ( reader != null ) reader.close(); }
            case Types.LONGVARCHAR:
            case Types.LONGNVARCHAR: // JDBC 4.0
                if ( runtime.is1_9() ) {
                    reader = resultSet.getCharacterStream(column);
                    try {
                        return readerToRuby(runtime, resultSet, reader);
                    }
                    finally { if ( reader != null ) reader.close(); }
                }
                else {
                    stream = resultSet.getBinaryStream(column);
                    try {
                        return streamToRuby(runtime, resultSet, stream);
                    }
                    finally { if ( stream != null ) stream.close(); }
                }
            case Types.TINYINT:
            case Types.SMALLINT:
            case Types.INTEGER:
                return integerToRuby(runtime, resultSet, resultSet.getLong(column));
            case Types.REAL:
            case Types.FLOAT:
            case Types.DOUBLE:
                return doubleToRuby(runtime, resultSet, resultSet.getDouble(column));
            case Types.BIGINT:
                return bigIntegerToRuby(runtime, resultSet, resultSet.getString(column));
            case Types.NUMERIC:
            case Types.DECIMAL:
                return decimalToRuby(runtime, resultSet, resultSet.getString(column));
            case Types.DATE:
                return dateToRuby(runtime, resultSet, resultSet.getDate(column));
            case Types.TIME:
                return timeToRuby(runtime, resultSet, resultSet.getTime(column));
            case Types.TIMESTAMP:
                return timestampToRuby(runtime, resultSet, resultSet.getTimestamp(column));
            case Types.BIT:
            case Types.BOOLEAN:
                return booleanToRuby(runtime, resultSet, resultSet.getBoolean(column));
            case Types.SQLXML: // JDBC 4.0
                final SQLXML xml = resultSet.getSQLXML(column);
                try {
                    return stringToRuby(runtime, resultSet, xml.getString());
                }
                finally { xml.free(); }
            case Types.NULL:
                return runtime.getNil();
            // NOTE: (JDBC) exotic stuff just cause it's so easy with JRuby :)
            case Types.JAVA_OBJECT:
            case Types.OTHER:
                return objectToRuby(runtime, resultSet, resultSet.getObject(column));
            case Types.ARRAY: // we handle JDBC Array into (Ruby) []
                final Array array = resultSet.getArray(column);
                try {
                    return arrayToRuby(runtime, resultSet, array);
                }
                finally { array.free(); }
            // (default) String
            case Types.CHAR:
            case Types.VARCHAR:
            case Types.NCHAR: // JDBC 4.0
            case Types.NVARCHAR: // JDBC 4.0
            default:
                return stringToRuby(runtime, resultSet, resultSet.getString(column));
            }
            // NOTE: not mapped types :
            //case Types.DISTINCT:
            //case Types.STRUCT:
            //case Types.REF:
            //case Types.DATALINK:
        }
        catch (IOException e) {
            throw new SQLException(e.getMessage(), e);
        }
    }

    protected IRubyObject integerToRuby(
        final Ruby runtime, final ResultSet resultSet, final long longValue)
        throws SQLException {
        if ( longValue == 0 && resultSet.wasNull() ) return runtime.getNil();

        return runtime.newFixnum(longValue);
    }

    protected IRubyObject doubleToRuby(Ruby runtime, ResultSet resultSet, double doubleValue)
        throws SQLException {
        if ( doubleValue == 0 && resultSet.wasNull() ) return runtime.getNil();
        return runtime.newFloat(doubleValue);
    }
    
    protected IRubyObject stringToRuby(
        final Ruby runtime, final ResultSet resultSet, final String string)
        throws SQLException {
        if ( string == null && resultSet.wasNull() ) return runtime.getNil();

        return RubyString.newUnicodeString(runtime, string);
    }
    
    protected IRubyObject bigIntegerToRuby(
        final Ruby runtime, final ResultSet resultSet, final String intValue) 
        throws SQLException {
        if ( intValue == null && resultSet.wasNull() ) return runtime.getNil();

        return RubyBignum.bignorm(runtime, new BigInteger(intValue));
    }
    
    protected IRubyObject decimalToRuby(
        final Ruby runtime, final ResultSet resultSet, final String decValue) 
        throws SQLException {
        if ( decValue == null && resultSet.wasNull() ) return runtime.getNil();
        // NOTE: JRuby 1.6 -> 1.7 API change : moved org.jruby.RubyBigDecimal
        return runtime.getKernel().callMethod("BigDecimal", runtime.newString(decValue));
    }
    
    private static boolean parseDateTime = false; // TODO
    
    protected IRubyObject dateToRuby( // TODO
        final Ruby runtime, final ResultSet resultSet, final Date date)
        throws SQLException {
        if ( date == null && resultSet.wasNull() ) return runtime.getNil();
        return RubyString.newUnicodeString(runtime, date.toString());
    }

    protected IRubyObject timeToRuby( // TODO
        final Ruby runtime, final ResultSet resultSet, final Time time)
        throws SQLException {
        if ( time == null && resultSet.wasNull() ) return runtime.getNil();
        return RubyString.newUnicodeString(runtime, time.toString());
    }
    
    protected IRubyObject timestampToRuby(
        final Ruby runtime, final ResultSet resultSet, final Timestamp timestamp)
        throws SQLException {
        if ( timestamp == null && resultSet.wasNull() ) return runtime.getNil();
        
        String format = timestamp.toString(); // yyyy-mm-dd hh:mm:ss.fffffffff
        if (format.endsWith(" 00:00:00.0")) {
            format = format.substring(0, format.length() - (" 00:00:00.0".length()));
        }
        if (format.endsWith(".0")) {
            format = format.substring(0, format.length() - (".0".length()));
        }
        
        return RubyString.newUnicodeString(runtime, format);
    }
    
    protected IRubyObject booleanToRuby(
        final Ruby runtime, final ResultSet resultSet, final boolean value)
        throws SQLException {
        if ( resultSet.wasNull() ) return runtime.getNil();
        return runtime.newBoolean(value);
    }
    
    protected static int streamBufferSize = 2048;
    
    protected IRubyObject streamToRuby(
        final Ruby runtime, final ResultSet resultSet, final InputStream stream)
        throws SQLException, IOException {
        if ( stream == null && resultSet.wasNull() ) return runtime.getNil();

        final int bufSize = streamBufferSize;
        final ByteList string = new ByteList(bufSize);
        
        final byte[] buf = new byte[bufSize];
        for (int len = stream.read(buf); len != -1; len = stream.read(buf)) {
            string.append(buf, 0, len);
        }

        return runtime.newString(string);
    }
    
    protected IRubyObject readerToRuby(
        final Ruby runtime, final ResultSet resultSet, final Reader reader)
        throws SQLException, IOException {
        if ( reader == null && resultSet.wasNull() ) return runtime.getNil();

        final int bufSize = streamBufferSize;
        final StringBuilder string = new StringBuilder(bufSize);
        
        final char[] buf = new char[bufSize];
        for (int len = reader.read(buf); len != -1; len = reader.read(buf)) {
            string.append(buf, 0, len);
        }
        
        return RubyString.newUnicodeString(runtime, string.toString());
    }

    private IRubyObject objectToRuby(
        final Ruby runtime, final ResultSet resultSet, final Object object)
        throws SQLException {
        if ( object == null && resultSet.wasNull() ) return runtime.getNil();
        
        return JavaUtil.convertJavaToRuby(runtime, object);
    }
    
    private IRubyObject arrayToRuby(
        final Ruby runtime, final ResultSet resultSet, final Array array)
        throws SQLException {
        if ( array == null && resultSet.wasNull() ) return runtime.getNil();
        
        final RubyArray rubyArray = runtime.newArray();
        
        final ResultSet arrayResult = array.getResultSet(); // 1: index, 2: value
        final int baseType = array.getBaseType();
        while ( arrayResult.next() ) {
            IRubyObject element = jdbcToRuby(runtime, 2, baseType, arrayResult);
            rubyArray.append(element);
        }
        return rubyArray;
    }
    
    protected final Connection getConnection() {
        return getConnection(false);
    }

    protected Connection getConnection(boolean error) {
        final Connection connection = (Connection) dataGetStruct();
        if ( connection == null && error ) {
            RubyClass err = getRuntime().getModule("ActiveRecord").getClass("ConnectionNotEstablished");
            throw new RaiseException(getRuntime(), err, "no connection available", false);
        }
        return connection;
    }
    
    private synchronized RubyJdbcConnection setConnection(final Connection connection) {
        close( getConnection(false) ); // close previously open connection if there is one
        
        final IRubyObject rubyConnectionObject = 
            connection != null ? convertJavaToRuby(connection) : getRuntime().getNil();
        setInstanceVariable( "@connection", rubyConnectionObject );
        dataWrapStruct(connection);
        return this;
    }

    private boolean isConnectionBroken(final ThreadContext context, final Connection connection) {
        Statement statement = null;
        try {
            final RubyString aliveSQL = getConfigValue(context, "connection_alive_sql").convertToString();
            if ( isSelect(aliveSQL) ) { // expect a SELECT/CALL SQL statement
                statement = connection.createStatement();
                statement.execute( aliveSQL.toString() );
                return false; // connection ain't broken
            }
            else { // alive_sql nil (or not a statement we can execute)
                return ! connection.isClosed(); // if closed than broken
            }
        }
        catch (Exception e) { // TODO log this
            return true;
        }
        finally { close(statement); }
    }
    
    private final static DateFormat FORMAT = new SimpleDateFormat("%y-%M-%d %H:%m:%s");

    private static void setValue(final ThreadContext context,
            final IRubyObject value, final IRubyObject type, 
            final PreparedStatement statement, final int index) throws SQLException {
        
        final int jdbcType = jdbcTypeFor(context, type);
        
        if ( value.isNil() ) {
            statement.setNull(index, jdbcType);
            return;
        }

        switch (jdbcType) {
        case Types.VARCHAR:
        case Types.CLOB:
            statement.setString(index, RubyString.objAsString(context, value).toString());
            break;
        case Types.INTEGER:
            statement.setLong(index, RubyNumeric.fix2long(value));
            break;
        case Types.FLOAT:
            statement.setDouble(index, ((RubyNumeric) value).getDoubleValue());
            break;
        case Types.TIMESTAMP:
        case Types.TIME:
        case Types.DATE:
            if ( ! ( value instanceof RubyTime ) ) {
                final String stringValue = RubyString.objAsString(context, value).toString();
                try {
                    Timestamp timestamp = new Timestamp( FORMAT.parse( stringValue ).getTime() );
                    statement.setTimestamp( index, timestamp, Calendar.getInstance() );
                }
                catch (Exception e) {
                    statement.setString( index, stringValue );
                }
            } else {
                final RubyTime timeValue = (RubyTime) value;
                final java.util.Date dateValue = timeValue.getJavaDate();
                
                long millis = dateValue.getTime();
                Timestamp timestamp = new Timestamp(millis);
                Calendar calendar = Calendar.getInstance();
                calendar.setTime(dateValue);
                if ( jdbcType != Types.DATE ) {
                    int micros = (int) timeValue.microseconds();
                    timestamp.setNanos( micros * 1000 ); // time.nsec ~ time.usec * 1000
                }
                statement.setTimestamp( index, timestamp, calendar );
            }
            break;
        case Types.BOOLEAN:
            statement.setBoolean(index, value.isTrue());
            break;
        default: throw new RuntimeException("type " + jdbcType + " not supported in _bind (yet)");
        }
    }

    private static void setValues(final ThreadContext context,
            final IRubyObject valuesArg, final IRubyObject typesArg,
            final PreparedStatement statement) throws SQLException {
        final RubyArray values = (RubyArray) valuesArg;
        final RubyArray types = (RubyArray) typesArg;
        for( int i = 0, j = values.getLength(); i < j; i++ ) {
            setValue(context, values.eltInternal(i), types.eltInternal(i), statement, i + 1);
        }
    }
    
    protected Callable<RubyArray> tableLookupBlock(final Ruby runtime,
            final String catalog, final String schemaPattern,
            final String tablePattern, final String[] types) {
        return new Callable<RubyArray>() {
            public RubyArray call(final Connection connection) throws SQLException {
                ResultSet tablesSet = null;
                try {
                    final DatabaseMetaData metaData = connection.getMetaData();
                    
                    String _tablePattern = tablePattern;
                    if (_tablePattern != null) _tablePattern = caseConvertIdentifierForJdbc(metaData, _tablePattern);
                    
                    String _schemaPattern = schemaPattern;
                    if (_schemaPattern != null) _schemaPattern = caseConvertIdentifierForJdbc(metaData, _schemaPattern);

                    tablesSet = metaData.getTables(catalog, _schemaPattern, _tablePattern, types);
                    return mapTables(runtime, metaData, catalog, _schemaPattern, _tablePattern, tablesSet);
                }
                finally { close(tablesSet); }
            }
        };
    }
    
    // NOTE java.sql.DatabaseMetaData.getTables :
    protected final static int TABLES_TABLE_CAT = 1;
    protected final static int TABLES_TABLE_SCHEM = 2;
    protected final static int TABLES_TABLE_NAME = 3;
    protected final static int TABLES_TABLE_TYPE = 4;
    
    /**
     * @param runtime
     * @param metaData
     * @param catalog
     * @param schemaPattern
     * @param tablePattern
     * @param tablesSet
     * @return List<RubyString>
     * @throws SQLException 
     */
    protected RubyArray mapTables(final Ruby runtime, final DatabaseMetaData metaData, 
            final String catalog, final String schemaPattern, final String tablePattern, 
            final ResultSet tablesSet) throws SQLException {
        final List<IRubyObject> tables = new ArrayList<IRubyObject>(32);
        while ( tablesSet.next() ) {
            String name = tablesSet.getString(TABLES_TABLE_NAME);
            name = caseConvertIdentifierForRails(metaData, name);
            tables.add(RubyString.newUnicodeString(runtime, name));
        }
        return runtime.newArray(tables);
    }

    protected static final int COLUMN_NAME = 4;
    protected static final int DATA_TYPE = 5;
    protected static final int TYPE_NAME = 6;
    protected static final int COLUMN_SIZE = 7;
    protected static final int DECIMAL_DIGITS = 9;
    protected static final int COLUMN_DEF = 13;
    protected static final int IS_NULLABLE = 18;

    protected int intFromResultSet(ResultSet resultSet, int column) throws SQLException {
        int precision = resultSet.getInt(column);

        return precision == 0 && resultSet.wasNull() ? -1 : precision;
    }

    /**
     * Create a string which represents a sql type usable by Rails from the resultSet column
     * metadata object.
     */
    protected String typeFromResultSet(final ResultSet resultSet) throws SQLException {
        final int precision = intFromResultSet(resultSet, COLUMN_SIZE);
        final int scale = intFromResultSet(resultSet, DECIMAL_DIGITS);

        final String type = resultSet.getString(TYPE_NAME);
        return formatTypeWithPrecisionAndScale(type, precision, scale);
    }

    protected static String formatTypeWithPrecisionAndScale(final String type, final int precision, final int scale) {
        if ( precision <= 0 ) return type;

        final StringBuilder typeStr = new StringBuilder().append(type);
        typeStr.append('(').append(precision); // type += "(" + precision;
        if ( scale > 0 ) typeStr.append(',').append(scale); // type += "," + scale;
        return typeStr.append(')').toString(); // type += ")";
    }

    private IRubyObject defaultValueFromResultSet(Ruby runtime, ResultSet resultSet)
            throws SQLException {
        String defaultValue = resultSet.getString(COLUMN_DEF);

        return defaultValue == null ? runtime.getNil() : RubyString.newUnicodeString(runtime, defaultValue);
    }

    private IRubyObject unmarshalColumns(final ThreadContext context, final DatabaseMetaData metaData, 
        final ResultSet results, final ResultSet primaryKeys) throws SQLException {
        
        final Ruby runtime = context.getRuntime();
        // RubyHash types = (RubyHash) native_database_types();
        final IRubyObject jdbcColumn = getJdbcColumnClass(context);

        final List<String> primarykeyNames = new ArrayList<String>();
        while ( primaryKeys.next() ) {
            primarykeyNames.add( primaryKeys.getString(COLUMN_NAME) );
        }

        final List<IRubyObject> columns = new ArrayList<IRubyObject>();
        while ( results.next() ) {
            final String colName = results.getString(COLUMN_NAME);
            IRubyObject column = jdbcColumn.callMethod(context, "new",
                new IRubyObject[] {
                    getInstanceVariable("@config"),
                    RubyString.newUnicodeString( runtime, caseConvertIdentifierForRails(metaData, colName) ),
                    defaultValueFromResultSet( runtime, results ),
                    RubyString.newUnicodeString( runtime, typeFromResultSet(results) ),
                    runtime.newBoolean( ! results.getString(IS_NULLABLE).trim().equals("NO") )
                });
            columns.add(column);

            if ( primarykeyNames.contains(colName) ) {
                column.callMethod(context, "primary=", runtime.getTrue());
            }
        }
        return runtime.newArray(columns);
    }

    protected static IRubyObject unmarshalIdResult(
        final Ruby runtime, final Statement statement) throws SQLException {
        final ResultSet genKeys = statement.getGeneratedKeys();
        try {
            if (genKeys.next() && genKeys.getMetaData().getColumnCount() > 0) {
                return runtime.newFixnum( genKeys.getLong(1) );
            }
            return runtime.getNil();
        }
        finally { close(genKeys); }
    }
    
    /**
     * @deprecated confusing as it closes the result set it receives use 
     * @see #unmarshalIdResult(Ruby, Statement)
     */
    @Deprecated
    public static IRubyObject unmarshal_id_result(
        final Ruby runtime, final ResultSet genKeys) throws SQLException {
        try {
            if (genKeys.next() && genKeys.getMetaData().getColumnCount() > 0) {
                return runtime.newFixnum( genKeys.getLong(1) );
            }
            return runtime.getNil();
        }
        finally { close(genKeys); }
     }

    protected IRubyObject unmarshalResults(final ThreadContext context, 
            final DatabaseMetaData metaData, final Statement statement, 
            final boolean downCase) throws SQLException {
        
        final Ruby runtime = context.getRuntime();
        IRubyObject result = unmarshalResult(context, runtime, metaData, statement.getResultSet(), downCase);
        
        if ( ! statement.getMoreResults() ) return result;
        
        final List<IRubyObject> results = new ArrayList<IRubyObject>();
        results.add(result);
        do {
            result = unmarshalResult(context, runtime, metaData, statement.getResultSet(), downCase);
            results.add(result);
        }
        while ( statement.getMoreResults() );

        return context.getRuntime().newArray(results);
    }

     /**
     * @deprecated no longer used but kept for API compatibility
     */
    @Deprecated
    protected IRubyObject unmarshalResult(final ThreadContext context,
            final DatabaseMetaData metaData, final ResultSet resultSet, 
            final boolean downCase) throws SQLException {
        return unmarshalResult(context, context.getRuntime(), metaData, resultSet, downCase);
    }
    
    /**
     * Converts a jdbc resultset into an array (rows) of hashes (row) that AR expects.
     *
     * @param downCase should column names only be in lower case?
     */
    private IRubyObject unmarshalResult(final ThreadContext context, final Ruby runtime,
            final DatabaseMetaData metaData, final ResultSet resultSet, 
            final boolean downCase) throws SQLException {
        
        final List<IRubyObject> results = new ArrayList<IRubyObject>();
        try {
            ColumnData[] columns = setupColumns(runtime, metaData, resultSet.getMetaData(), downCase);

            populateFromResultSet(context, runtime, results, resultSet, columns);
        }
        finally { close(resultSet); }

        return runtime.newArray(results);
    }
    
    /**
     * @deprecated renamed and parameterized to {@link #withConnection(ThreadContext, SQLBlock)}
     */
    @Deprecated
    @SuppressWarnings("unchecked")
    protected Object withConnectionAndRetry(final ThreadContext context, final SQLBlock block) 
        throws RaiseException {
        return withConnection(context, block);
    }
    
    protected <T> T withConnection(final ThreadContext context, final Callable<T> block) 
        throws RaiseException {
        try {
            return withConnection(context, true, block);
        }
        catch (final SQLException e) {
            return handleException(context, e); // should never happen
        }
    }
    
    private <T> T withConnection(final ThreadContext context, final boolean handleException, final Callable<T> block) 
        throws RaiseException, RuntimeException, SQLException {
        
        Throwable exception = null; int tries = 1; int i = 0;
        
        while ( i++ < tries ) {
            final Connection connection = getConnection(true);
            boolean autoCommit = true; // retry in-case getAutoCommit throws
            try {
                autoCommit = connection.getAutoCommit();
                return block.call(connection);
            }
            catch (final Exception e) { // SQLException or RuntimeException
                exception = e;

                if ( autoCommit ) { // do not retry if (inside) transactions
                    if ( i == 1 ) {
                        IRubyObject retryCount = getConfigValue(context, "retry_count");
                        tries = (int) retryCount.convertToInteger().getLongValue();
                        if ( tries <= 0 ) tries = 1;
                    }
                    if ( isConnectionBroken(context, connection) ) {
                        reconnect(context); continue; // retry connection (block) again
                    }
                    break; // connection not broken yet failed
                }
            }
        }
        // (retry) loop ended and we did not return ... exception != null
        if ( handleException ) {
            return handleException(context, getCause(exception)); // throws
        }
        else {
            if ( exception instanceof SQLException ) {
                throw (SQLException) exception;
            }
            if ( exception instanceof RuntimeException ) {
                throw (RuntimeException) exception;
            }
            // won't happen - our try block only throws SQL or Runtime exceptions
            throw new RuntimeException(exception);
        }
    }

    private static Throwable getCause(Throwable exception) {
        Throwable cause = exception.getCause();
        while (cause != null && cause != exception) {
            // SQLException's cause might be DB specific (checked/unchecked) :
            if ( exception instanceof SQLException ) break;
            exception = cause; cause = exception.getCause();
        }
        return exception;
    }

    protected <T> T handleException(final ThreadContext context, Throwable exception) 
        throws RaiseException {
        // NOTE: we shall not wrap unchecked (runtime) exceptions into AR::Error
        // if it's really a misbehavior of the driver throwing a RuntimeExcepion
        // instead of SQLException than this should be overriden for the adapter
        if ( exception instanceof RuntimeException ) {
            throw (RuntimeException) exception;
        }
        debugStackTrace(context, exception);
        throw wrapException(context, exception);
    }
    
    /**
     * @deprecated use {@link #wrapException(ThreadContext, Throwable)} instead
     * for overriding how exceptions are handled use {@link #handleException(ThreadContext, Throwable)}
     */
    @Deprecated
    protected RuntimeException wrap(final ThreadContext context, final Throwable exception) {
        return wrapException(context, exception);
    }
    
    protected RaiseException wrapException(final ThreadContext context, final Throwable exception) {
        final Ruby runtime = context.getRuntime();
        if ( exception instanceof SQLException ) {
            final String message = SQLException.class == exception.getClass() ? 
                exception.getMessage() : exception.toString(); // useful to easily see type on Ruby side
            final RaiseException error = wrapException(context, getJDBCError(runtime), exception, message);
            final int errorCode = ((SQLException) exception).getErrorCode();
            RuntimeHelpers.invoke( context, error.getException(),
                "errno=", runtime.newFixnum(errorCode) );
            RuntimeHelpers.invoke( context, error.getException(),
                "sql_exception=", JavaEmbedUtils.javaToRuby(runtime, exception) );
            return error;
        }
        return wrapException(context, getJDBCError(runtime), exception);
    }

    protected static RaiseException wrapException(final ThreadContext context, 
        final RubyClass errorClass, final Throwable exception) {
        return wrapException(context, errorClass, exception, exception.toString());
    }

    protected static RaiseException wrapException(final ThreadContext context, 
        final RubyClass errorClass, final Throwable exception, final String message) {
        final RaiseException error = new RaiseException(context.getRuntime(), errorClass, message, true);
        error.initCause(exception);
        return error;
    }
    
    private IRubyObject convertJavaToRuby(final Connection connection) {
        return JavaUtil.convertJavaToRuby( getRuntime(), connection );
    }

    /**
     * Some databases support schemas and others do not.
     * For ones which do this method should return true, aiding in decisions regarding schema vs database determination.
     */
    protected boolean databaseSupportsSchemas() {
        return false;
    }

    private static final byte[] SELECT = new byte[] { 's','e','l','e','c','t' };
    private static final byte[] WITH = new byte[] { 'w','i','t','h' };
    private static final byte[] SHOW = new byte[] { 's','h','o','w' };
    private static final byte[] CALL = new byte[]{ 'c','a','l','l' };
    
    @JRubyMethod(name = "select?", required = 1, meta = true, frame = false)
    public static IRubyObject select_p(final ThreadContext context, 
        final IRubyObject self, final IRubyObject sql) {
        return context.getRuntime().newBoolean( isSelect(sql.convertToString()) );
    }

    private static boolean isSelect(final RubyString sql) {
        final ByteList sqlBytes = sql.getByteList();
        return startsWithIgnoreCase(sqlBytes, SELECT) || 
               startsWithIgnoreCase(sqlBytes, WITH) ||
               startsWithIgnoreCase(sqlBytes, SHOW) || 
               startsWithIgnoreCase(sqlBytes, CALL);
    }
    
    private static final byte[] INSERT = new byte[] { 'i','n','s','e','r','t' };
    
    @JRubyMethod(name = "insert?", required = 1, meta = true, frame = false)
    public static IRubyObject insert_p(final ThreadContext context, 
        final IRubyObject self, final IRubyObject sql) {
        final ByteList sqlBytes = sql.convertToString().getByteList();
        return context.getRuntime().newBoolean(startsWithIgnoreCase(sqlBytes, INSERT));
    }

    protected static boolean startsWithIgnoreCase(final ByteList string, final byte[] start) {
        int p = skipWhitespace(string, string.begin);
        if ( string.bytes[p] == '(' ) p = skipWhitespace(string, p + 1);

        for ( int i = 0; i < string.realSize && i < start.length; i++ ) {
            if ( Character.toLowerCase(string.bytes[p + i]) != start[i] ) return false;
        }
        return true;
    }

    private static int skipWhitespace(final ByteList string, final int from) {
        final int end = string.begin + string.realSize;
        for ( int i = from; i < end; i++ ) {
            if ( ! Character.isWhitespace( string.bytes[i] ) ) return i;
        }
        return end;
    }
    
    protected static final class TableName {
        
        public final String catalog, schema, name;

        public TableName(String catalog, String schema, String table) {
            this.catalog = catalog;
            this.schema = schema;
            this.name = table;
        }
        
    }
    
    /**
     * Extract the table name components for the given name e.g. "mycat.sys.entries"
     * 
     * @param connection
     * @param catalog (optional) catalog to use if table name does not contain 
     *                 the catalog prefix
     * @param schema (optional) schema to use if table name does not have one
     * @param tableName the table name
     * @return (parsed) table name
     * 
     * @throws IllegalArgumentException for invalid table name format
     * @throws SQLException 
     */
    protected TableName extractTableName(
            final Connection connection, String catalog, String schema, 
            final String tableName) throws IllegalArgumentException, SQLException {

        final String[] nameParts = tableName.split("\\.");
        if ( nameParts.length > 3 ) {
            throw new IllegalArgumentException("table name: " + tableName + " should not contain more than 2 '.'");
        }

        String name = tableName;
        
        if ( nameParts.length == 2 ) {
            schema = nameParts[0];
            name = nameParts[1];
        }
        else if ( nameParts.length == 3 ) {
            catalog = nameParts[0];
            schema = nameParts[1];
            name = nameParts[2];
        }
        
        final DatabaseMetaData metaData = connection.getMetaData();
        
        if (schema != null) {
            schema = caseConvertIdentifierForJdbc(metaData, schema);
        }
        name = caseConvertIdentifierForJdbc(metaData, name);

        if (schema != null && ! databaseSupportsSchemas()) {
            catalog = schema;
        }
        if (catalog == null) catalog = connection.getCatalog();

        return new TableName(catalog, schema, name);
    }
    
    /**
     * @deprecated use {@link #extractTableName(Connection, String, String, String)}
     */
    @Deprecated
    protected TableName extractTableName(
            final Connection connection, final String schema, 
            final String tableName) throws IllegalArgumentException, SQLException {
        return extractTableName(connection, null, schema, tableName);
    }

    protected static final class ColumnData {
        
        public final RubyString name;
        public final int index;
        public final int type;

        public ColumnData(RubyString name, int type, int idx) {
            this.name = name;
            this.type = type;
            this.index = idx;
        }
        
    }
    
    private static ColumnData[] setupColumns(
            final Ruby runtime, 
            final DatabaseMetaData metaData,
            final ResultSetMetaData resultMetaData, 
            final boolean downCase) throws SQLException {

        final int columnCount = resultMetaData.getColumnCount();
        final ColumnData[] columns = new ColumnData[columnCount];

        for ( int i = 1; i <= columnCount; i++ ) { // metadata is one-based
            final String name;
            if (downCase) {
                name = resultMetaData.getColumnLabel(i).toLowerCase();
            } else {
                name = caseConvertIdentifierForRails(metaData, resultMetaData.getColumnLabel(i));
            }
            final int columnType = resultMetaData.getColumnType(i);
            final RubyString columnName = RubyString.newUnicodeString(runtime, name);
            columns[i - 1] = new ColumnData(columnName, columnType, i);
        }

        return columns;
    }
    
    // JDBC API Helpers :
    
    protected static void close(final Connection connection) {
        if ( connection != null ) {
            try { connection.close(); }
            catch (final Exception e) { /* NOOP */ }
        }
    }

    public static void close(final ResultSet resultSet) {
        if (resultSet != null) {
            try { resultSet.close(); }
            catch (final Exception e) { /* NOOP */ }
        }
    }

    public static void close(final Statement statement) {
        if (statement != null) {
            try { statement.close(); }
            catch (final Exception e) { /* NOOP */ }
        }
    }
    
    // DEBUG-ing helpers :
    
    private static boolean debug = Boolean.getBoolean("arjdbc.debug");

    public static boolean isDebug() { return debug; }
    
    public static void setDebug(boolean debug) {
        RubyJdbcConnection.debug = debug;
    }
    
    protected static void debugMessage(final ThreadContext context, final String msg) {
        if ( debug || context.runtime.isDebug() ) {
            context.runtime.getOut().println(msg);
        }
    }
    
    protected static void debugErrorSQL(final ThreadContext context, final String sql) {
        if ( debug || context.runtime.isDebug() ) {
            context.runtime.getOut().println("Error SQL: " + sql);
        }
    }
    
    private static void debugStackTrace(final ThreadContext context, final Throwable e) {
        if ( debug || context.runtime.isDebug() ) {
            e.printStackTrace(context.runtime.getOut());
        }
    }
    
}
