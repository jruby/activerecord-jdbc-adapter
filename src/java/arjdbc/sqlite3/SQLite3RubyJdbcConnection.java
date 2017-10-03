/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2013 Karol Bucek <self@kares.org>
 * Copyright (c) 2006-2010 Nick Sieger <nick@nicksieger.com>
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

package arjdbc.sqlite3;

import arjdbc.jdbc.Callable;
import arjdbc.jdbc.RubyJdbcConnection;

import java.io.IOException;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.Savepoint;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.RubyTime;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 *
 * @author enebo
 */
public class SQLite3RubyJdbcConnection extends RubyJdbcConnection {
    private static final long serialVersionUID = -5783855018818472773L;

    protected SQLite3RubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createSQLite3JdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime). // ActiveRecord::ConnectionAdapters
            defineClassUnder("SQLite3JdbcConnection", jdbcConnection, SQLITE3_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods( SQLite3RubyJdbcConnection.class );
        getConnectionAdapters(runtime).setConstant("Sqlite3JdbcConnection", clazz); // backwards-compat
        return clazz;
    }

    private static ObjectAllocator SQLITE3_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new SQLite3RubyJdbcConnection(runtime, klass);
        }
    };

    @JRubyMethod(name = {"last_insert_rowid", "last_insert_id"}, alias = "last_insert_row_id")
    public IRubyObject last_insert_rowid(final ThreadContext context)
        throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null; ResultSet genKeys = null;
                try {
                    statement = connection.createStatement();
                    // NOTE: strangely this will work and has been used for quite some time :
                    //return mapGeneratedKeys(context.getRuntime(), connection, statement, true);
                    // but we should assume SQLite JDBC will prefer sane API usage eventually :
                    genKeys = statement.executeQuery("SELECT last_insert_rowid()");
                    return doMapGeneratedKeys(context.getRuntime(), genKeys, true);
                }
                catch (final SQLException e) {
                    debugMessage(context, "failed to get generated keys: " + e.getMessage());
                    throw e;
                }
                finally { close(genKeys); close(statement); }
            }
        });
    }

    // NOTE: interestingly it supports getGeneratedKeys but not executeUpdate
    // + the driver does not report it supports it via the meta-data yet does
    @Override
    protected boolean supportsGeneratedKeys(final Connection connection) throws SQLException {
        return true;
    }

    @Override
    protected Statement createStatement(final ThreadContext context, final Connection connection)
        throws SQLException {
        final Statement statement = connection.createStatement();
        IRubyObject statementEscapeProcessing = getConfigValue(context, "statement_escape_processing");
        if ( ! statementEscapeProcessing.isNil() ) {
            statement.setEscapeProcessing(statementEscapeProcessing.isTrue());
        }
        // else leave as is by default
        return statement;
    }

    @Override
    protected IRubyObject indexes(final ThreadContext context, String table, final String name, String schema) {
        if ( table != null ) {
            final int i = table.indexOf('.');
            if ( i > 0 && schema == null ) {
                schema = table.substring(0, i);
                table = table.substring(i + 1);
            }
        }
        final String tableName = table;
        final String schemaName = schema;
        // return super.indexes(context, tableName, name, schemaName);
        return withConnection(context, new Callable<IRubyObject>() {
            public RubyArray call(final Connection connection) throws SQLException {
                final Ruby runtime = context.runtime;
                final RubyClass indexDefinition = getIndexDefinition(runtime);

                final TableName table = extractTableName(connection, null, schemaName, tableName);

                final List<RubyString> primaryKeys = primaryKeys(context, connection, table);

                final DatabaseMetaData metaData = connection.getMetaData();
                ResultSet indexInfoSet = null;
                try {
                    indexInfoSet = metaData.getIndexInfo(table.catalog, table.schema, table.name, false, true);
                }
                catch (SQLException e) {
                    final String msg = e.getMessage();
                    if ( msg != null && msg.startsWith("[SQLITE_ERROR] SQL error or missing database") ) {
                        return RubyArray.newEmptyArray(runtime); // on 3.8.7 getIndexInfo fails if table has no indexes
                    }
                    throw e;
                }
                final RubyArray indexes = RubyArray.newArray(runtime, 8);
                try {
                    String currentIndex = null;

                    while ( indexInfoSet.next() ) {
                        String indexName = indexInfoSet.getString(INDEX_INFO_NAME);
                        if ( indexName == null ) continue;

                        final String columnName = indexInfoSet.getString(INDEX_INFO_COLUMN_NAME);
                        final RubyString rubyColumnName = RubyString.newUnicodeString(runtime, columnName);
                        if ( primaryKeys.contains(rubyColumnName) ) continue;

                        // We are working on a new index
                        if ( ! indexName.equals(currentIndex) ) {
                            currentIndex = indexName;

                            String indexTableName = indexInfoSet.getString(INDEX_INFO_TABLE_NAME);

                            final boolean nonUnique = indexInfoSet.getBoolean(INDEX_INFO_NON_UNIQUE);

                            IRubyObject[] args = new IRubyObject[] {
                                RubyString.newUnicodeString(runtime, indexTableName), // table_name
                                RubyString.newUnicodeString(runtime, indexName), // index_name
                                runtime.newBoolean( ! nonUnique ), // unique
                                runtime.newArray() // [] for column names, we'll add to that in just a bit
                                // orders, (since AR 3.2) where, type, using (AR 4.0)
                            };

                            indexes.append( indexDefinition.callMethod(context, "new", args) ); // IndexDefinition.new
                        }

                        // One or more columns can be associated with an index
                        IRubyObject lastIndexDef = indexes.isEmpty() ? null : indexes.entry(-1);
                        if ( lastIndexDef != null ) {
                            ( (RubyArray) lastIndexDef.callMethod(context, "columns") ).append(rubyColumnName);
                        }
                    }

                    return indexes;

                } finally { close(indexInfoSet); }
            }
        });
    }

    @Override
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

        if ( schema != null ) {
            // NOTE: hack to work-around SQLite JDBC ignoring schema :
            return new TableName(catalog, null, schema + '.' + name);
        }
        return new TableName(catalog, schema, name);
    }

    @Override
    protected IRubyObject jdbcToRuby(final ThreadContext context,
        final Ruby runtime, final int column, int type, final ResultSet resultSet)
        throws SQLException {
        // This is rather gross, and only needed because the resultset metadata for SQLite tries to be overly
        // clever, and returns a type for the column of the "current" row, so an integer value stored in a
        // decimal column is returned as Types.INTEGER.  Therefore, if the first row of a resultset was an
        // integer value, all rows of that result set would get truncated.
        if ( resultSet instanceof ResultSetMetaData ) {
            type = ((ResultSetMetaData) resultSet).getColumnType(column);
        }
        // since JDBC 3.8 there seems to be more cleverness built-in that
        // seems (<= 3.8.7) to get things wrong ... reports DATE SQL type
        // for "datetime" columns :
        if ( type == Types.DATE ) {
            // return timestampToRuby(context, runtime, resultSet, column);
            return stringToRuby(context, runtime, resultSet, column);
        }
        return super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    @Override
    protected IRubyObject streamToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException, IOException {
        final byte[] bytes = resultSet.getBytes(column);
        if ( resultSet.wasNull() ) return runtime.getNil();
        return runtime.newString( new ByteList(bytes, false) );
    }

    @Override
    protected RubyArray mapTables(final Ruby runtime, final DatabaseMetaData metaData,
            final String catalog, final String schemaPattern, final String tablePattern,
            final ResultSet tablesSet) throws SQLException {
        final List<IRubyObject> tables = new ArrayList<IRubyObject>(32);
        while ( tablesSet.next() ) {
            String name = tablesSet.getString(TABLES_TABLE_NAME);
            name = name.toLowerCase(); // simply lower-case for SQLite3
            tables.add( RubyString.newUnicodeString(runtime, name) );
        }
        return runtime.newArray(tables);
    }

    private static class SavepointStub implements Savepoint {

        @Override
        public int getSavepointId() throws SQLException {
            throw new UnsupportedOperationException();
        }

        @Override
        public String getSavepointName() throws SQLException {
            throw new UnsupportedOperationException();
        }

    }

    @Override
    public IRubyObject begin(ThreadContext context, IRubyObject level) {
        throw context.runtime.newRaiseException(ActiveRecord(context).getClass("TransactionIsolationError"),
                "SQLite3 does not support isolation levels");
    }

    @Override
    @JRubyMethod(name = "create_savepoint", optional = 1)
    public IRubyObject create_savepoint(final ThreadContext context, final IRubyObject[] args) {
        final IRubyObject name = args.length > 0 ? args[0] : null;
        if ( name == null || name.isNil() ) {
            throw new IllegalArgumentException("create_savepoint (without name) not implemented!");
        }
        final Connection connection = getConnection(context, true);
        try {
            connection.setAutoCommit(false);
            // NOTE: JDBC driver does not support setSavepoint(String) :
            connection.createStatement().execute("SAVEPOINT " + name.toString());

            getSavepoints(context).put(name, new SavepointStub());

            return name;
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @Override
    @JRubyMethod(name = "rollback_savepoint", required = 1)
    public IRubyObject rollback_savepoint(final ThreadContext context, final IRubyObject name) {
        final Connection connection = getConnection(context, true);
        try {
            if ( getSavepoints(context).get(name) == null ) {
                throw context.getRuntime().newRuntimeError("could not rollback savepoint: '" + name + "' (not set)");
            }
            // NOTE: JDBC driver does not implement rollback(Savepoint) :
            connection.createStatement().execute("ROLLBACK TO SAVEPOINT " + name.toString());

            return context.getRuntime().getNil();
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }

    // FIXME: Update our JDBC adapter to later version which basically performs this SQL in
    // this method.  Then we can use base RubyJdbcConnection version.
    @Override
    @JRubyMethod(name = "release_savepoint", required = 1)
    public IRubyObject release_savepoint(final ThreadContext context, final IRubyObject name) {
        Ruby runtime = context.runtime;

        try {
            if (getSavepoints(context).remove(name) == null) {
                RubyClass invalidStatement = ActiveRecord(context).getClass("StatementInvalid");
                throw runtime.newRaiseException(invalidStatement, "could not release savepoint: '" + name + "' (not set)");
            }
            // NOTE: JDBC driver does not implement release(Savepoint) :
            getConnection(context, true).createStatement().execute("RELEASE SAVEPOINT " + name.toString());

            return runtime.getNil();
        } catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @Override
    protected void setBooleanParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {
        // Apparently active record stores booleans in sqlite as 't' and 'f' instead of the built in 1/0
        statement.setString(index, value.isTrue() ? "t" : "f");
    }

    // Treat dates as strings, this can potentially be removed if we update
    // the driver to the latest and tell it to store dates/times as text
    @Override
    protected void setDateParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        setStringParameter(context, connection, statement, index, value, attribute, type);
    }

    // The current driver doesn't support dealing with BigDecimal values, so force everything to doubles
    @Override
    protected void setDecimalParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        setDoubleParameter(context, connection, statement, index, value, attribute, type);
    }

    // Treat times as strings
    @Override
    protected void setTimeParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        setStringParameter(context, connection, statement, index, value, attribute, type);
    }

    // Treat timestamps as strings
    @Override
    protected void setTimestampParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        IRubyObject valueForDB = value;

        if ( valueForDB instanceof RubyTime ) {
            // Make sure we handle usec values
            valueForDB = ((RubyTime) valueForDB).strftime(context.runtime.newString("%F %T.%N%:z"));
        }

        setStringParameter(context, connection, statement, index, valueForDB, attribute, type);
    }
}
