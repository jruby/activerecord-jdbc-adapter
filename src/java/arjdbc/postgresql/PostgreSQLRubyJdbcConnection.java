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
package arjdbc.postgresql;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Collection;
import java.util.HashSet;
import java.util.UUID;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author enebo
 */
public class PostgreSQLRubyJdbcConnection extends arjdbc.jdbc.RubyJdbcConnection {
    
    protected PostgreSQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createPostgreSQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("PostgreSQLJdbcConnection", jdbcConnection, POSTGRESQL_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(PostgreSQLRubyJdbcConnection.class);
        getConnectionAdapters(runtime).setConstant("PostgresJdbcConnection", clazz); // backwards-compat
        return clazz;
    }
    
    private static ObjectAllocator POSTGRESQL_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new PostgreSQLRubyJdbcConnection(runtime, klass);
        }
    };
    
    @Override
    protected String caseConvertIdentifierForJdbc(final DatabaseMetaData metaData, final String value)
        throws SQLException {
        if ( value != null ) {
            if ( metaData.storesUpperCaseIdentifiers() ) {
                return value.toUpperCase();
            }
            // for PostgreSQL we do not care about storesLowerCaseIdentifiers()
        }
        return value;
    }
    
    /**
     * Override jdbcToRuby type conversions to handle infinite timestamps.
     * Handing timestamp off to ruby as string so adapter can perform type
     * conversion to timestamp
     */
    @Override
    protected IRubyObject jdbcToRuby(final Ruby runtime, 
        final int column, final int type, final ResultSet resultSet)
        throws SQLException {
        switch ( type ) {
            case Types.TIMESTAMP:
                return stringToRuby(runtime, resultSet, resultSet.getString(column));
            //case Types.JAVA_OBJECT: case Types.OTHER:
                //return objectToRuby(runtime, resultSet, resultSet.getObject(column));
            case Types.ARRAY:
                // NOTE: avoid `finally { array.free(); }` on PostgreSQL due :
                // java.sql.SQLFeatureNotSupportedException: 
                // Method org.postgresql.jdbc4.Jdbc4Array.free() is not yet implemented.
                return arrayToRuby(runtime, resultSet, resultSet.getArray(column));
        }
        return super.jdbcToRuby(runtime, column, type, resultSet);
    }
    
    // TODO this is just a fast-draft for now :
    private static final Collection<String> PG_TYPES = new HashSet<String>();
    static {
        PG_TYPES.add("org.postgresql.util.PGobject");
        PG_TYPES.add("org.postgresql.util.PGmoney");
        PG_TYPES.add("org.postgresql.util.PGInterval");
        PG_TYPES.add("org.postgresql.geometric.PGbox");
        PG_TYPES.add("org.postgresql.geometric.PGcircle");
        PG_TYPES.add("org.postgresql.geometric.PGline");
        PG_TYPES.add("org.postgresql.geometric.PGlseg");
        PG_TYPES.add("org.postgresql.geometric.PGpath");
        PG_TYPES.add("org.postgresql.geometric.PGpoint");
        PG_TYPES.add("org.postgresql.geometric.PGpolygon");
    }
    
    @Override
    protected IRubyObject objectToRuby(
        final Ruby runtime, final ResultSet resultSet, final Object object)
        throws SQLException {
        if ( object == null && resultSet.wasNull() ) return runtime.getNil();
        
        if ( object.getClass() == UUID.class ) {
            return runtime.newString( object.toString() );
        }
        // NOTE: this should get refactored using PG's JDBC API :
        if ( PG_TYPES.contains(object.getClass().getName()) ) {
            return runtime.newString( object.toString() );
        }
        
        return JavaUtil.convertJavaToRuby(runtime, object);
    }
    
    @Override
    protected TableName extractTableName(
        final Connection connection, String catalog, String schema, 
        final String tableName) throws IllegalArgumentException, SQLException {
        // The postgres JDBC driver will default to searching every schema if no
        // schema search path is given.  Default to the 'public' schema instead:
        if ( schema == null ) schema = "public";
        return super.extractTableName(connection, catalog, schema, tableName);
    }
    
}
