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
package arjdbc.mssql;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.List;

import arjdbc.jdbc.RubyJdbcConnection;
import static arjdbc.jdbc.RubyJdbcConnection.ColumnData;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
public class MssqlRubyJdbcConnection extends RubyJdbcConnection {

    private RubyString _row_num;

    protected MssqlRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
        _row_num = runtime.newString("_row_num");
    }

    public static RubyClass createMssqlJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).defineClassUnder("MssqlJdbcConnection",
                jdbcConnection, MSSQL_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(MssqlRubyJdbcConnection.class);

        return clazz;
    }

    private static ObjectAllocator MSSQL_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new MssqlRubyJdbcConnection(runtime, klass);
        }
    };

    protected static IRubyObject booleanToRuby(Ruby runtime, ResultSet resultSet, boolean booleanValue)
            throws SQLException {
        if (booleanValue == false && resultSet.wasNull()) return runtime.getNil();
        return runtime.newBoolean(booleanValue);
    }

    /**
     * Treat LONGVARCHAR as CLOB on Mssql for purposes of converting a JDBC value to Ruby.
     * Treat BOOLEAN/BIT as Boolean, rather than the default behaviour of conversion to string
     */
    @Override
    protected IRubyObject jdbcToRuby(Ruby runtime, int column, int type, ResultSet resultSet)
            throws SQLException {
        if ( Types.BOOLEAN == type || Types.BIT == type ) {
          return booleanToRuby(runtime, resultSet, resultSet.getBoolean(column));
        }
        if (type == Types.LONGVARCHAR) {
            type = Types.CLOB;
        }
        return super.jdbcToRuby(runtime, column, type, resultSet);
    }

    /**
     * Microsoft SQL 2000+ support schemas
     */
    @Override
    protected boolean databaseSupportsSchemas() {
        return true;
    }

    @Override
    protected void populateFromResultSet(ThreadContext context, Ruby runtime, List results,
                                         ResultSet resultSet, ColumnData[] columns) throws SQLException {
        super.populateFromResultSet(context, runtime, results, resultSet, filterRowNumFromColumns(columns));
    }

    /**
     * Filter out the <tt>_row_num</tt> column from results.
     */
    private ColumnData[] filterRowNumFromColumns(ColumnData[] columns) {
        for (int i = 0; i < columns.length; i++) {
            if (columns[i].name.equals(_row_num)) {
                ColumnData[] filtered = new ColumnData[columns.length - 1];
                if (i > 0) {
                    System.arraycopy(columns, 0, filtered, 0, i);
                }

                if (i + 1 < columns.length) {
                    System.arraycopy(columns, i + 1, filtered, i, columns.length - (i + 1));
                }

                return filtered;
            }
        }

        return columns;
    }
}
