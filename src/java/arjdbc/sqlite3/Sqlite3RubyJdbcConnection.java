/*
 **** BEGIN LICENSE BLOCK *****
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

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;

import arjdbc.jdbc.RubyJdbcConnection;
import arjdbc.jdbc.SQLBlock;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author enebo
 */
public class Sqlite3RubyJdbcConnection extends RubyJdbcConnection {
    protected Sqlite3RubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createSqlite3JdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).defineClassUnder("Sqlite3JdbcConnection",
                jdbcConnection, SQLITE3_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(Sqlite3RubyJdbcConnection.class);

        return clazz;
    }

    private static ObjectAllocator SQLITE3_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Sqlite3RubyJdbcConnection(runtime, klass);
        }
    };

    @JRubyMethod(name = "last_insert_row_id")
    public IRubyObject getLastInsertRowId(final ThreadContext context) 
        throws SQLException {
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
                public Object call(Connection c) throws SQLException {
                    Statement stmt = null;
                    try {
                        stmt = c.createStatement();
                        return unmarshal_id_result(context.getRuntime(),
                                                   stmt.getGeneratedKeys());
                    } catch (SQLException sqe) {
                        if (context.getRuntime().isDebug()) {
                            System.out.println("Error SQL:" + sqe.getMessage());
                        }
                        throw sqe;
                    } finally {
                        close(stmt);
                    }
                }
            });
    }

    @Override
    protected IRubyObject tables(ThreadContext context, String catalog, String schemaPattern, String tablePattern, String[] types) {
        return (IRubyObject) withConnectionAndRetry(context, tableLookupBlock(context.getRuntime(), catalog, schemaPattern, tablePattern, types, true));
    }

    @Override
    protected IRubyObject jdbcToRuby(Ruby runtime, int column, int type, ResultSet resultSet)
            throws SQLException {
        try {
            // This is rather gross, and only needed because the resultset metadata for SQLite tries to be overly
            // clever, and returns a type for the column of the "current" row, so an integer value stored in a 
            // decimal column is returned as Types.INTEGER.  Therefore, if the first row of a resultset was an
            // integer value, all rows of that result set would get truncated.
            if( resultSet instanceof ResultSetMetaData ) {
                type = ((ResultSetMetaData)resultSet).getColumnType(column);
            }
            switch (type) {
            case Types.BINARY:
            case Types.BLOB:
            case Types.LONGVARBINARY:
            case Types.VARBINARY:
                return streamToRuby(runtime, resultSet, new ByteArrayInputStream(resultSet.getBytes(column)));
            case Types.LONGVARCHAR:
                return runtime.is1_9() ?
                    readerToRuby(runtime, resultSet, resultSet.getCharacterStream(column)) :
                    streamToRuby(runtime, resultSet, new ByteArrayInputStream(resultSet.getBytes(column)));
            default:
                return super.jdbcToRuby(runtime, column, type, resultSet);
            }
        } catch (IOException ioe) {
            throw (SQLException) new SQLException(ioe.getMessage()).initCause(ioe);
        }
    }
}
