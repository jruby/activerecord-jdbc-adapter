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
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.SQLXML;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collection;
import java.util.Date;
import java.util.List;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBignum;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyModule;
import org.jruby.RubyNumeric;
import org.jruby.RubyObject;
import org.jruby.RubyObjectAdapter;
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
    private static final String[] TABLE_TYPE = new String[]{"TABLE"};
    private static final String[] TABLE_TYPES = new String[]{"TABLE", "VIEW", "SYNONYM"};

    private static RubyObjectAdapter rubyApi;

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

        rubyApi = JavaEmbedUtils.newObjectAdapter();

        return jdbcConnection;
    }

    protected static RubyModule getConnectionAdapters(Ruby runtime) {
        return (RubyModule) runtime.getModule("ActiveRecord").getConstant("ConnectionAdapters");
    }

    @JRubyMethod(name = "begin")
    public IRubyObject begin(ThreadContext context) throws SQLException {
        final Ruby runtime = context.getRuntime();
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
          public Object call(Connection c) throws SQLException {
            getConnection(true).setAutoCommit(false);
            return runtime.getNil();
          }
        });
    }
    
    @JRubyMethod(name = "commit")
    public IRubyObject commit(ThreadContext context) throws SQLException {
        Connection connection = getConnection(true);

        if (!connection.getAutoCommit()) {
            try {
                connection.commit();
            } finally {
                connection.setAutoCommit(true);
            }
        }

        return context.getRuntime().getNil();
    }

    @JRubyMethod(name = "connection")
    public IRubyObject connection() {
        if ( getConnection(false) == null ) { 
            synchronized (this) {
                if ( getConnection(false) == null ) {
                    reconnect();
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
            for ( Object element : backtrace ) runtime.getOut().println(element);
            runtime.getOut().flush();
        }
        return setConnection(null);
    }

    @JRubyMethod(name = "reconnect!")
    public IRubyObject reconnect() {
        return setConnection( getConnectionFactory().newConnection() );
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
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(Connection c) throws SQLException {
                Statement stmt = null;
                String query = sql.convertToString().getUnicodeValue();
                try {
                    stmt = c.createStatement();
                    if (genericExecute(stmt, query)) {
                        return unmarshalResults(context, c.getMetaData(), stmt, false);
                    } else {
                        return unmarshalKeysOrUpdateCount(context, c, stmt);
                    }
                } catch (SQLException sqe) {
                    if (context.getRuntime().isDebug()) {
                        System.out.println("Error SQL: " + query);
                    }
                    throw sqe;
                } finally {
                    close(stmt);
                }
            }
        });
    }

    protected boolean genericExecute(Statement stmt, String query) throws SQLException {
        return stmt.execute(query);
    }

    protected IRubyObject unmarshalKeysOrUpdateCount(ThreadContext context, Connection c, Statement stmt) throws SQLException {
        IRubyObject key = context.getRuntime().getNil();
        if (c.getMetaData().supportsGetGeneratedKeys()) {
            key = unmarshal_id_result(context.getRuntime(), stmt.getGeneratedKeys());
        }
        if (key.isNil()) {
            return context.getRuntime().newFixnum(stmt.getUpdateCount());
        } else {
            return key;
        }
    }

    @JRubyMethod(name = "execute_id_insert", required = 2)
    public IRubyObject execute_id_insert(final ThreadContext context, final IRubyObject sql,
            final IRubyObject id) throws SQLException {
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(Connection c) throws SQLException {
                String insert = sql.convertToString().getUnicodeValue();
                PreparedStatement ps = c.prepareStatement(insert);
                try {
                    ps.setLong(1, RubyNumeric.fix2long(id));
                    ps.executeUpdate();
                } catch (SQLException sqe) {
                    if (context.getRuntime().isDebug()) {
                        System.out.println("Error SQL: " + insert);
                    }
                    throw sqe;
                } finally {
                    close(ps);
                }
                return id;
            }
        });
    }

    @JRubyMethod(name = "execute_insert", required = 1)
    public IRubyObject execute_insert(final ThreadContext context, final IRubyObject sql)
            throws SQLException {
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(Connection c) throws SQLException {
                Statement stmt = null;
                String insert = rubyApi.convertToRubyString(sql).getUnicodeValue();
                try {
                    stmt = c.createStatement();
                    stmt.executeUpdate(insert, Statement.RETURN_GENERATED_KEYS);
                    return unmarshal_id_result(context.getRuntime(), stmt.getGeneratedKeys());
                } catch (SQLException sqe) {
                    if (context.getRuntime().isDebug()) {
                        System.out.println("Error SQL: " + insert);
                    }
                    throw sqe;
                } finally {
                    close(stmt);
                }
            }
        });
    }

    @JRubyMethod(name = "execute_query", required = 1)
    public IRubyObject execute_query(final ThreadContext context, IRubyObject sql)
            throws SQLException, IOException {
        String query = sql.convertToString().getUnicodeValue();
        return executeQuery(context, query, 0);
    }

    @JRubyMethod(name = "execute_query", required = 2)
    public IRubyObject execute_query(final ThreadContext context, IRubyObject sql,
            IRubyObject max_rows) throws SQLException, IOException {
        String query = sql.convertToString().getUnicodeValue();
        final int maxRows = RubyNumeric.fix2int(max_rows);
        return executeQuery(context, query, maxRows);
    }

    protected IRubyObject executeQuery(final ThreadContext context, final String query, final int maxRows) {
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(Connection c) throws SQLException {
                Statement stmt = null;
                try {
                    DatabaseMetaData metadata = c.getMetaData();
                    stmt = c.createStatement();
                    stmt.setMaxRows(maxRows);
                    return unmarshalResult(context, metadata, stmt.executeQuery(query), false);
                } catch (SQLException sqe) {
                    if (context.getRuntime().isDebug()) {
                        System.out.println("Error SQL: " + query);
                    }
                    throw sqe;
                } finally {
                    close(stmt);
                }
            }
        });
    }
    
    @JRubyMethod(name = {"execute_update", "execute_delete"}, required = 1)
    public IRubyObject execute_update(final ThreadContext context, final IRubyObject sql)
        throws SQLException {
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(Connection c) throws SQLException {
                Statement stmt = null;
                String update = sql.convertToString().getUnicodeValue();
                try {
                    stmt = c.createStatement();
                    return context.getRuntime().newFixnum((long)stmt.executeUpdate(update));
                } catch (SQLException sqe) {
                    if (context.getRuntime().isDebug()) {
                        System.out.println("Error SQL: " + update);
                    }
                    throw sqe;
                } finally {
                    close(stmt);
                }
            }
        });
    }

    @JRubyMethod(name = "native_database_types", frame = false)
    public IRubyObject native_database_types() {
        return getInstanceVariable("@native_database_types");
    }


    @JRubyMethod(name = "primary_keys", required = 1)
    public IRubyObject primary_keys(ThreadContext context, IRubyObject tableName) throws SQLException {
        return context.getRuntime().newArray((List) primaryKeys(context, tableName.toString()));
    }

    private static final int PRIMARY_KEYS_COLUMN_NAME = 4;
    
    protected List<RubyString> primaryKeys(final ThreadContext context, final String tableName) {
        return (List<RubyString>) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(Connection c) throws SQLException {
                final Ruby runtime = context.getRuntime();
                DatabaseMetaData metaData = c.getMetaData();
                final String _tableName = caseConvertIdentifierForJdbc(metaData, tableName);
                ResultSet resultSet = null;
                final List<RubyString> keyNames = new ArrayList<RubyString>();
                try {
                    TableName components = extractTableName(c, null, _tableName);
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


    @JRubyMethod(name = "rollback")
    public IRubyObject rollback(ThreadContext context) throws SQLException {
        final Ruby runtime = context.getRuntime();
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
          public Object call(Connection c) throws SQLException {
            Connection connection = getConnection(true);

            if (!connection.getAutoCommit()) {
                try {
                    connection.rollback();
                } finally {
                    connection.setAutoCommit(true);
                }
            }

            return runtime.getNil();
          }
        });
    }
    
    @JRubyMethod(name = "set_native_database_types")
    public IRubyObject set_native_database_types(ThreadContext context) throws SQLException, IOException {
        Ruby runtime = context.getRuntime();
        DatabaseMetaData metadata = getConnection(true).getMetaData();
        IRubyObject types = unmarshalResult(context, metadata, metadata.getTypeInfo(), true);
        IRubyObject typeConverter = getConnectionAdapters(runtime).getConstant("JdbcTypeConverter");
        IRubyObject value = rubyApi.callMethod(rubyApi.callMethod(typeConverter, "new", types), "choose_best_types");
        setInstanceVariable("@native_types", value);

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
        return (IRubyObject) withConnectionAndRetry(context, tableLookupBlock(context.getRuntime(), catalog, schemaPattern, tablePattern, types));
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
        
        return (RubyBoolean) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(final Connection connection) throws SQLException {
                final TableName components = 
                    extractTableName(connection, tableSchema, tableName);
                
                final Collection matchingTables = (Collection) tableLookupBlock(
                    runtime, components.catalog, components.schema, components.name, getTableTypes()
                ).call(connection);
                
                return runtime.newBoolean( ! matchingTables.isEmpty() );
            }
        });
    }
    
    @JRubyMethod(name = {"columns", "columns_internal"}, required = 1, optional = 2)
    public IRubyObject columns_internal(final ThreadContext context, final IRubyObject[] args)
            throws SQLException, IOException {
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(final Connection connection) throws SQLException {
                ResultSet columns = null, primaryKeys = null;
                try {
                    String defaultSchema = args.length > 2 ? toStringOrNull(args[2]) : null;
                    String tableName = rubyApi.convertToRubyString(args[0]).getUnicodeValue();
                    TableName components = extractTableName(connection, defaultSchema, tableName);

                    Collection matchingTables = (Collection) tableLookupBlock(context.getRuntime(),
                            components.catalog, components.schema, components.name, getTableTypes()).call(connection);
                    if (matchingTables.isEmpty()) {
                        throw new SQLException("table: " + tableName + " does not exist");
                    }

                    final DatabaseMetaData metaData = connection.getMetaData();
                    columns = metaData.getColumns(components.catalog, components.schema, components.name, null);
                    primaryKeys = metaData.getPrimaryKeys(components.catalog, components.schema, components.name);
                    return unmarshal_columns(context, metaData, columns, primaryKeys);
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
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(final Connection connection) throws SQLException {
                final Ruby runtime = context.getRuntime();
                final RubyModule indexDefinition = getConnectionAdapters(runtime).getClass("IndexDefinition");
                
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
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(final Connection connection) throws SQLException {
                final String sql = args[0].convertToString().toString();
                PreparedStatement statement = null;
                try {
                    statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
                    setValues(context, args[1], args[2], statement);
                    statement.executeUpdate();
                    return unmarshal_id_result(runtime, statement.getGeneratedKeys());
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
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(final Connection connection) throws SQLException {
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
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(Connection c) throws SQLException {
                return block.call(context, new IRubyObject[] { wrappedConnection(c) });
            }
        });
    }

    /*
     * (is binary?, colname, tablename, primary_key, id, lob_value)
     */
    @JRubyMethod(name = "write_large_object", required = 6)
    public IRubyObject write_large_object(final ThreadContext context, final IRubyObject[] args)
        throws SQLException, IOException {
        
        final boolean isBinary = args[0].isTrue(); 
        final RubyString columnName = args[1].convertToString();
        final RubyString tableName = args[2].convertToString();
        final RubyString idKey = args[3].convertToString();
        final RubyString idVal = args[4].convertToString();
        final IRubyObject lobValue = args[5];
        
        final Ruby runtime = context.getRuntime();
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            public Object call(final Connection connection) throws SQLException {
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

    // helpers
    protected static void close(Connection connection) {
        if (connection != null) {
            try {
                connection.close();
            } catch(Exception e) {}
        }
    }

    public static void close(ResultSet resultSet) {
        if (resultSet != null) {
            try {
                resultSet.close();
            } catch(Exception e) {}
        }
    }

    public static void close(Statement statement) {
        if (statement != null) {
            try {
                statement.close();
            } catch(Exception e) {}
        }
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

    protected IRubyObject doubleToRuby(Ruby runtime, ResultSet resultSet, double doubleValue)
            throws SQLException, IOException {
        if (doubleValue == 0 && resultSet.wasNull()) return runtime.getNil();
        return runtime.newFloat(doubleValue);
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

    private static String[] getTypes(IRubyObject typeArg) {
        if (!(typeArg instanceof RubyArray)) return new String[] { typeArg.toString() };

        IRubyObject[] arr = rubyApi.convertToJavaArray(typeArg);
        String[] types = new String[arr.length];
        for (int i = 0; i < types.length; i++) {
            types[i] = arr[i].toString();
        }

        return types;
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

        // Assumption; If this is a symbol then it will be backed by an interned string. (enebo)
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
        else return -1;
    }

    protected void populateFromResultSet(ThreadContext context, Ruby runtime, List results,
            ResultSet resultSet, ColumnData[] columns) throws SQLException {
        int columnCount = columns.length;

        while (resultSet.next()) {
            RubyHash row = RubyHash.newHash(runtime);

            for (int i = 0; i < columnCount; i++) {
                row.op_aset(context, columns[i].name, jdbcToRuby(runtime, columns[i].index, columns[i].type, resultSet));
            }

            results.add(row);
        }
    }
    
    protected IRubyObject jdbcToRuby(Ruby runtime, int column, int type, ResultSet resultSet)
        throws SQLException {
        try {
            switch (type) {
            case Types.BINARY:
            case Types.BLOB:
            case Types.LONGVARBINARY:
            case Types.VARBINARY:
                return streamToRuby(runtime, resultSet, resultSet.getBinaryStream(column));
            case Types.LONGVARCHAR:
                return runtime.is1_9() ?
                    readerToRuby(runtime, resultSet, resultSet.getCharacterStream(column)) :
                    streamToRuby(runtime, resultSet, resultSet.getBinaryStream(column));
            case Types.CLOB:
                return readerToRuby(runtime, resultSet, resultSet.getCharacterStream(column));
            case Types.TIMESTAMP:
                return timestampToRuby(runtime, resultSet, resultSet.getTimestamp(column));
            case Types.INTEGER:
            case Types.SMALLINT:
            case Types.TINYINT:
                return integerToRuby(runtime, resultSet, resultSet.getLong(column));
            case Types.REAL:
                return doubleToRuby(runtime, resultSet, resultSet.getDouble(column));
            case Types.BIGINT:
                return bigIntegerToRuby(runtime, resultSet, resultSet.getString(column));
            case Types.SQLXML:
                final SQLXML xml = resultSet.getSQLXML(column);
                return stringToRuby(runtime, resultSet, xml.getString());
            default:
                return stringToRuby(runtime, resultSet, resultSet.getString(column));
            }
        }
        catch (IOException ioe) {
            throw (SQLException) new SQLException(ioe.getMessage()).initCause(ioe);
        }
    }

    protected IRubyObject integerToRuby(
        final Ruby runtime, final ResultSet resultSet, final long longValue)
        throws SQLException {
        if ( longValue == 0 && resultSet.wasNull() ) return runtime.getNil();

        return runtime.newFixnum(longValue);
    }

    protected IRubyObject bigIntegerToRuby(
        final Ruby runtime, final ResultSet resultSet, final String bigint) 
        throws SQLException {
        if ( bigint == null && resultSet.wasNull() ) return runtime.getNil();

        return RubyBignum.bignorm(runtime, new BigInteger(bigint));
    }
    
    protected IRubyObject streamToRuby(
        final Ruby runtime, final ResultSet resultSet, final InputStream is)
        throws SQLException, IOException {
        if ( is == null && resultSet.wasNull() ) return runtime.getNil();

        ByteList str = new ByteList(2048);
        try {
            byte[] buf = new byte[2048];

            for (int n = is.read(buf); n != -1; n = is.read(buf)) {
                str.append(buf, 0, n);
            }
        } finally {
            is.close();
        }

        return runtime.newString(str);
    }

    protected IRubyObject stringToRuby(
        final Ruby runtime, final ResultSet resultSet, final String string)
        throws SQLException, IOException {
        if ( string == null && resultSet.wasNull() ) return runtime.getNil();

        return RubyString.newUnicodeString(runtime, string);
    }
    
    protected IRubyObject timestampToRuby(
        final Ruby runtime, final ResultSet resultSet, final Timestamp time)
        throws SQLException {
        if ( time == null && resultSet.wasNull() ) return runtime.getNil();
        
        String str = time.toString();
        if (str.endsWith(" 00:00:00.0")) {
            str = str.substring(0, str.length() - (" 00:00:00.0".length()));
        }
        if (str.endsWith(".0")) {
            str = str.substring(0, str.length() - (".0".length()));
        }
        
        return RubyString.newUnicodeString(runtime, str);
    }
    
    protected IRubyObject readerToRuby(
        final Ruby runtime, final ResultSet resultSet, final Reader reader)
        throws SQLException, IOException {
        if ( reader == null && resultSet.wasNull() ) return runtime.getNil();

        final StringBuilder str = new StringBuilder(2048);
        try {
            char[] buf = new char[2048];

            for (int n = reader.read(buf); n != -1; n = reader.read(buf)) {
                str.append(buf, 0, n);
            }
        }
        finally {
            reader.close();
        }
        
        return RubyString.newUnicodeString(runtime, str.toString());
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
            connection != null ? wrappedConnection(connection) : getRuntime().getNil();
        setInstanceVariable( "@connection", rubyConnectionObject );
        dataWrapStruct(connection);
        return this;
    }

    private boolean isConnectionBroken(final ThreadContext context, final Connection connection) {
        try {
            final IRubyObject alive_sql = getConfigValue(context, "connection_alive_sql");
            if ( select_p(context, this, alive_sql).isTrue() ) {
                String aliveSQL = rubyApi.convertToRubyString(alive_sql).toString();
                Statement statement = connection.createStatement();
                try {
                    statement.execute(aliveSQL);
                }
                finally { close(statement); }
                return false;
            } else {
                return ! connection.isClosed();
            }
        }
        catch (Exception e) { // TODO log this
            return true;
        }
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
                final Date dateValue = timeValue.getJavaDate();
                
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
    
    protected SQLBlock tableLookupBlock(final Ruby runtime,
            final String catalog, final String schemaPattern,
            final String tablePattern, final String[] types) {
        return new SQLBlock() {
            public Object call(final Connection connection) throws SQLException {
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
    
    protected RubyArray mapTables(final Ruby runtime, final DatabaseMetaData metaData, 
            final String catalog, final String schemaPattern, final String tablePattern, 
            final ResultSet tablesSet) throws SQLException {
        final List<RubyString> tables = new ArrayList<RubyString>(32);
        while ( tablesSet.next() ) {
            String name = tablesSet.getString(TABLES_TABLE_NAME);
            name = caseConvertIdentifierForRails(metaData, name);
            tables.add(RubyString.newUnicodeString(runtime, name));
        }
        return runtime.newArray((List) tables);
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

    private IRubyObject unmarshal_columns(ThreadContext context, DatabaseMetaData metadata,
                                          ResultSet rs, ResultSet pkeys) throws SQLException {
        try {
            Ruby runtime = context.getRuntime();
            List columns = new ArrayList();
            List pkeyNames = new ArrayList();
            String clzName = metadata.getClass().getName().toLowerCase();

            RubyHash types = (RubyHash) native_database_types();
            IRubyObject jdbcCol = getJdbcColumnClass(context);

            while (pkeys.next()) {
                pkeyNames.add(pkeys.getString(COLUMN_NAME));
            }

            while (rs.next()) {
                String colName = rs.getString(COLUMN_NAME);
                IRubyObject column = jdbcCol.callMethod(context, "new",
                        new IRubyObject[] {
                            getInstanceVariable("@config"),
                            RubyString.newUnicodeString(runtime,
                                    caseConvertIdentifierForRails(metadata, colName)),
                            defaultValueFromResultSet(runtime, rs),
                            RubyString.newUnicodeString(runtime, typeFromResultSet(rs)),
                            runtime.newBoolean(!rs.getString(IS_NULLABLE).trim().equals("NO"))
                        });
                columns.add(column);

                if (pkeyNames.contains(colName)) {
                    column.callMethod(context, "primary=", runtime.getTrue());
                }
            }
            return runtime.newArray(columns);
        } finally {
            close(rs);
        }
    }


    public static IRubyObject unmarshal_id_result(Ruby runtime, ResultSet rs) throws SQLException {
        try {
            if (rs.next() && rs.getMetaData().getColumnCount() > 0) {
                return runtime.newFixnum(rs.getLong(1));
            }
            return runtime.getNil();
        } finally {
            close(rs);
        }
    }

    protected IRubyObject unmarshalResults(ThreadContext context, DatabaseMetaData metadata,
                                           Statement stmt, boolean downCase) throws SQLException {
        
        IRubyObject result = unmarshalResult(context, metadata, stmt.getResultSet(), downCase);
        
        if ( ! stmt.getMoreResults() ) return result;
        
        final List<IRubyObject> results = new ArrayList<IRubyObject>();
        results.add(result);
        do {
            result = unmarshalResult(context, metadata, stmt.getResultSet(), downCase);
            results.add(result);
        }
        while ( stmt.getMoreResults() );

        return context.getRuntime().newArray(results);
    }

    /**
     * Converts a jdbc resultset into an array (rows) of hashes (row) that AR expects.
     *
     * @param downCase should column names only be in lower case?
     */
    protected IRubyObject unmarshalResult(ThreadContext context, DatabaseMetaData metadata,
                                          ResultSet resultSet, boolean downCase) throws SQLException {
        final Ruby runtime = context.getRuntime();
        final List<IRubyObject> results = new ArrayList<IRubyObject>();
        try {
            ColumnData[] columns = setupColumns(runtime, metadata, resultSet.getMetaData(), downCase);

            populateFromResultSet(context, runtime, results, resultSet, columns);
        }
        finally { close(resultSet); }

        return runtime.newArray(results);
    }

    protected Object withConnectionAndRetry(ThreadContext context, SQLBlock block) {
        int tries = 1;
        int i = 0;
        Throwable toWrap = null;
        boolean autoCommit = false;
        while (i < tries) {
            Connection c = getConnection(true);
            try {
                autoCommit = c.getAutoCommit();
                return block.call(c);
            }
            catch (Exception e) {
                toWrap = e;
                while (toWrap.getCause() != null && toWrap.getCause() != toWrap) {
                    toWrap = toWrap.getCause();
                }

                if (context.getRuntime().isDebug()) {
                    toWrap.printStackTrace(System.out);
                }

                i++;
                if (autoCommit) {
                    if (i == 1) {
                        IRubyObject retryCount = getConfigValue(context, "retry_count");
                        tries = (int) retryCount.convertToInteger().getLongValue();
                        if ( tries <= 0 ) tries = 1;
                    }
                    if (isConnectionBroken(context, c)) {
                        reconnect();
                    } else {
                        throw wrap(context, toWrap);
                    }
                }
            }
        }
        throw wrap(context, toWrap);
    }

    protected RuntimeException wrap(ThreadContext context, Throwable exception) {
        Ruby runtime = context.getRuntime();
        RaiseException arError = new RaiseException(runtime, runtime.getModule("ActiveRecord").getClass("JDBCError"),
                                                    exception.getMessage(), true);
        arError.initCause(exception);
        if (exception instanceof SQLException) {
            RuntimeHelpers.invoke(context, arError.getException(),
                                  "errno=", runtime.newFixnum(((SQLException) exception).getErrorCode()));
            RuntimeHelpers.invoke(context, arError.getException(),
                                  "sql_exception=", JavaEmbedUtils.javaToRuby(runtime, exception));
        }
        return (RuntimeException) arError;
    }

    private IRubyObject wrappedConnection(final Connection connection) {
        return JavaUtil.convertJavaToRuby( getRuntime(), connection );
    }

    /**
     * Some databases support schemas and others do not.
     * For ones which do this method should return true, aiding in decisions regarding schema vs database determination.
     */
    protected boolean databaseSupportsSchemas() {
        return false;
    }

    private static final byte[] SELECT = new byte[] { 's', 'e', 'l', 'e', 'c', 't' };
    private static final byte[] WITH = new byte[] { 'w', 'i', 't', 'h' };
    private static final byte[] SHOW = new byte[] { 's', 'h', 'o', 'w' };
    private static final byte[] CALL = new byte[]{ 'c', 'a', 'l', 'l' };
    
    @JRubyMethod(name = "select?", required = 1, meta = true, frame = false)
    public static IRubyObject select_p(ThreadContext context, IRubyObject self, IRubyObject sql) {
        final ByteList sqlBytes = sql.convertToString().getByteList();
        return context.getRuntime().newBoolean(
                startsWithIgnoreCase(sqlBytes, SELECT) || 
                startsWithIgnoreCase(sqlBytes, WITH) ||
                startsWithIgnoreCase(sqlBytes, SHOW) || 
                startsWithIgnoreCase(sqlBytes, CALL)
        );
    }

    private static final byte[] INSERT = new byte[] { 'i', 'n', 's', 'e', 'r', 't' };
    
    @JRubyMethod(name = "insert?", required = 1, meta = true, frame = false)
    public static IRubyObject insert_p(ThreadContext context, IRubyObject recv, IRubyObject _sql) {
        ByteList sql = rubyApi.convertToRubyString(_sql).getByteList();

        return context.getRuntime().newBoolean(startsWithIgnoreCase(sql, INSERT));
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
    
    protected TableName extractTableName(
            final Connection connection, 
            final String defaultSchema, 
            final String tableName) throws IllegalArgumentException, SQLException {

        final String[] nameParts = tableName.split("\\.");
        if (nameParts.length > 3) {
            throw new IllegalArgumentException("table name: " + tableName + " should not contain more than 2 '.'");
        }

        String catalog = null;
        String schemaName = defaultSchema;
        String name = tableName;
        
        if (nameParts.length == 2) {
            schemaName = nameParts[0];
            name = nameParts[1];
        }
        else if (nameParts.length == 3) {
            catalog = nameParts[0];
            schemaName = nameParts[1];
            name = nameParts[2];
        }
        
        final DatabaseMetaData metaData = connection.getMetaData();
        
        if (schemaName != null) { 
            schemaName = caseConvertIdentifierForJdbc(metaData, schemaName);
        }
        name = caseConvertIdentifierForJdbc(metaData, name);

        if (schemaName != null && ! databaseSupportsSchemas()) {
            catalog = schemaName;
        }
        if (catalog == null) catalog = connection.getCatalog();

        return new TableName(catalog, schemaName, name);
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
    
}
