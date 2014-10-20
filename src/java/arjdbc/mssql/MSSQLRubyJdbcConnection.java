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
package arjdbc.mssql;

import arjdbc.jdbc.Callable;
import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;

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
 * @author nicksieger
 */
//@org.jruby.anno.JRubyClass(name = "ActiveRecord::ConnectionAdapters::MSSQLJdbcConnection")
public class MSSQLRubyJdbcConnection extends RubyJdbcConnection {
    private static final long serialVersionUID = -745716565005219263L;

    public MSSQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createMSSQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime). // ActiveRecord::ConnectionAdapters
            defineClassUnder("MSSQLJdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(MSSQLRubyJdbcConnection.class);
        return clazz;
    }

    public static RubyClass load(final Ruby runtime) {
        RubyClass jdbcConnection = getJdbcConnectionClass(runtime);
        return createMSSQLJdbcConnectionClass(runtime, jdbcConnection);
    }

    protected static ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new MSSQLRubyJdbcConnection(runtime, klass);
        }
    };

    private static final byte[] EXEC = new byte[] { 'e', 'x', 'e', 'c' };

    @JRubyMethod(name = "exec?", required = 1, meta = true, frame = false)
    public static IRubyObject exec_p(ThreadContext context, IRubyObject self, IRubyObject sql) {
        final ByteList sqlBytes = sql.convertToString().getByteList();
        return context.runtime.newBoolean( startsWithIgnoreCase(sqlBytes, EXEC) );
    }

    @Override
    protected RubyArray mapTables(final Ruby runtime, final DatabaseMetaData metaData,
            final String catalog, final String schemaPattern, final String tablePattern,
            final ResultSet tablesSet) throws SQLException, IllegalStateException {

        final RubyArray tables = runtime.newArray();

        while ( tablesSet.next() ) {
            String schema = tablesSet.getString(TABLES_TABLE_SCHEM);
            if ( schema != null ) schema = schema.toLowerCase();
            // Under MS-SQL, don't return system tables/views unless explicitly asked for :
            if ( schemaPattern == null &&
                ( "sys".equals(schema) || "information_schema".equals(schema) ) ) {
                continue;
            }
            String name = tablesSet.getString(TABLES_TABLE_NAME);
            if ( name == null ) {
                // NOTE: seems there's a jTDS but when doing getColumns while
                // EXPLAIN is on (e.g. `SET SHOWPLAN_TEXT ON`) not returning
                // correct result set with table info (null NAME, invalid CAT)
                throw new IllegalStateException("got null name while matching table(s): [" +
                    catalog + "." + schemaPattern + "." + tablePattern + "] check " +
                    "if this happened during EXPLAIN (SET SHOWPLAN_TEXT ON) if so please try " +
                    "turning it off using the system property 'arjdbc.mssql.explain_support.disabled=true' " +
                    "or programatically by changing: `ArJdbc::MSSQL::ExplainSupport::DISABLED`");
            }
            name = caseConvertIdentifierForRails(metaData, name);
            tables.add(RubyString.newUnicodeString(runtime, name));
        }
        return tables;
    }

    /**
     * Microsoft SQL 2000+ support schemas
     */
    @Override
    protected boolean databaseSupportsSchemas() {
        return true;
    }

    /**
     * Treat LONGVARCHAR as CLOB on MSSQL for purposes of converting a JDBC value to Ruby.
     */
    @Override
    protected IRubyObject jdbcToRuby(
        final ThreadContext context, final Ruby runtime,
        final int column, int type, final ResultSet resultSet)
        throws SQLException {
        if ( type == Types.LONGVARCHAR || type == Types.LONGNVARCHAR ) type = Types.CLOB;
        return super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    @Override
    protected ColumnData[] extractColumns(final ThreadContext context,
        final Connection connection, final ResultSet resultSet,
        final boolean downCase) throws SQLException {
        return filterRowNumFromColumns( super.extractColumns(context, connection, resultSet, downCase) );
    }

    /**
     * Filter out the <tt>_row_num</tt> column from results.
     */
    private static ColumnData[] filterRowNumFromColumns(final ColumnData[] columns) {
        for ( int i = 0; i < columns.length; i++ ) {
            if ( "_row_num".equals( columns[i].getName() ) ) {
                final ColumnData[] filtered = new ColumnData[columns.length - 1];

                if ( i > 0 ) {
                    System.arraycopy(columns, 0, filtered, 0, i);
                }

                if ( i + 1 < columns.length ) {
                    System.arraycopy(columns, i + 1, filtered, i, columns.length - (i + 1));
                }

                return filtered;
            }
        }
        return columns;
    }

    // internal helper not meant as a "public" API - used in one place thus every
    @JRubyMethod(name = "jtds_driver?")
    public IRubyObject jtds_driver_p(final ThreadContext context) throws SQLException {
        // "jTDS Type 4 JDBC Driver for MS SQL Server and Sybase"
        // SQLJDBC: "Microsoft JDBC Driver 4.0 for SQL Server"
        return withConnection(context, new Callable<IRubyObject>() {
            // NOTE: only used in one place for now (on release_savepoint) ...
            // might get optimized to only happen once since driver won't change
            public IRubyObject call(final Connection connection) throws SQLException {
                final String driver = connection.getMetaData().getDriverName();
                return context.runtime.newBoolean( driver.indexOf("jTDS") >= 0 );
            }
        });
    }

}
