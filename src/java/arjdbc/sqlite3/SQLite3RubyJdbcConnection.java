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
import java.sql.Savepoint;
import java.util.ArrayList;
import java.util.List;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyString;
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
            tables.add(RubyString.newUnicodeString(runtime, name));
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
    @JRubyMethod(name = "create_savepoint", optional = 1)
    public IRubyObject create_savepoint(final ThreadContext context, final IRubyObject[] args) {
        IRubyObject name = args.length > 0 ? args[0] : null;
        final Connection connection = getConnection(true);
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
        final Connection connection = getConnection(true);
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

    @Override
    @JRubyMethod(name = "release_savepoint", required = 1)
    public IRubyObject release_savepoint(final ThreadContext context, final IRubyObject name) {
        final Connection connection = getConnection(true);
        try {
            if ( getSavepoints(context).get(name) == null ) {
                throw context.getRuntime().newRuntimeError("could not release savepoint: '" + name + "' (not set)");
            }
            // NOTE: JDBC driver does not implement release(Savepoint) :
            connection.createStatement().execute("RELEASE SAVEPOINT " + name.toString());

            return context.getRuntime().getNil();
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }

}
