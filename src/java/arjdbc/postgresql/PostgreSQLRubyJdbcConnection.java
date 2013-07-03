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

import java.sql.Array;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.UUID;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.postgresql.util.PGInterval;
import org.postgresql.util.PGobject;

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

    @Override
    protected int jdbcTypeFor(final ThreadContext context, final Ruby runtime,
        final IRubyObject column, final Object value) throws SQLException {
        // NOTE: likely wrong but native adapters handles this thus we should
        // too - used from #table_exists? `binds << [ nil, schema ] if schema`
        if ( column == null || column.isNil() ) return Types.VARCHAR; // assume type == :string
        return super.jdbcTypeFor(context, runtime, column, value);
    }

    /**
     * Override jdbcToRuby type conversions to handle infinite timestamps.
     * Handing timestamp off to ruby as string so adapter can perform type
     * conversion to timestamp
     */
    @Override
    protected IRubyObject jdbcToRuby(
        final ThreadContext context, final Ruby runtime,
        final int column, final int type, final ResultSet resultSet)
        throws SQLException {
        switch ( type ) {
            case Types.BIT:
                // we do get BIT for 't' 'f' as well as BIT strings e.g. "0110" :
                final String bits = resultSet.getString(column);
                if ( bits == null ) return runtime.getNil();
                if ( bits.length() > 1 ) {
                    return RubyString.newUnicodeString(runtime, bits);
                }
                return booleanToRuby(context, runtime, resultSet, column);
            //case Types.JAVA_OBJECT: case Types.OTHER:
                //return objectToRuby(runtime, resultSet, resultSet.getObject(column));
        }
        return super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    @Override
    protected IRubyObject timestampToRuby(final ThreadContext context, // TODO
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        // NOTE: using Timestamp we loose information such as BC :
        // Timestamp: '0001-12-31 22:59:59.0' String: '0001-12-31 22:59:59 BC'
        final String value = resultSet.getString(column);
        if ( value == null ) {
            if ( resultSet.wasNull() ) return runtime.getNil();
            return runtime.newString(); // ""
        }
        return timestampToRubyString(runtime, value);
    }

    @Override
    protected IRubyObject arrayToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        // NOTE: avoid `finally { array.free(); }` on PostgreSQL due :
        // java.sql.SQLFeatureNotSupportedException:
        // Method org.postgresql.jdbc4.Jdbc4Array.free() is not yet implemented.
        final Array value = resultSet.getArray(column);

        if ( value == null && resultSet.wasNull() ) return runtime.getNil();

        final RubyArray array = runtime.newArray();

        final ResultSet arrayResult = value.getResultSet(); // 1: index, 2: value
        final int baseType = value.getBaseType();
        while ( arrayResult.next() ) {
            array.append( jdbcToRuby(context, runtime, 2, baseType, arrayResult) );
        }
        return array;
    }

    @Override
    protected IRubyObject objectToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final Object object = resultSet.getObject(column);

        if ( object == null && resultSet.wasNull() ) return runtime.getNil();

        final Class<?> objectClass = object.getClass();
        if ( objectClass == UUID.class ) {
            return runtime.newString( object.toString() );
        }

        if ( objectClass == PGInterval.class ) {
            return runtime.newString( formatInterval(object) );
        }

        if ( object instanceof PGobject ) {
            // PG 9.2 JSON type will be returned here as well
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

    // NOTE: do not use PG classes in the API so that loading is delayed !
    private String formatInterval(final Object object) {
        final PGInterval interval = (PGInterval) object;
        if ( useRawIntervalType() ) return interval.getValue();

        final StringBuilder str = new StringBuilder(32);

        final int years = interval.getYears();
        if ( years != 0 ) str.append(years).append(" years ");
        final int months = interval.getMonths();
        if ( months != 0 ) str.append(months).append(" months ");
        final int days = interval.getDays();
        if ( days != 0 ) str.append(days).append(" days ");
        final int hours = interval.getHours();
        final int mins = interval.getMinutes();
        final int secs = (int) interval.getSeconds();
        if ( hours != 0 || mins != 0 || secs != 0 ) { // xx:yy:zz if not all 00
            if ( hours < 10 ) str.append('0');
            str.append(hours).append(':');
            if ( mins < 10 ) str.append('0');
            str.append(mins).append(':');
            if ( secs < 10 ) str.append('0');
            str.append(secs);
        }
        else {
            if ( str.length() > 1 ) str.deleteCharAt( str.length() - 1 ); // " " at the end
        }

        return str.toString();
    }

    // whether to use "raw" interval values off by default - due native adapter compatibilty :
    // RAW values :
    // - 2 years 0 mons 0 days 0 hours 3 mins 0.00 secs
    // - -1 years 0 mons -2 days 0 hours 0 mins 0.00 secs
    // Rails style :
    // - 2 years 00:03:00
    // - -1 years -2 days
    private static boolean rawIntervalType = Boolean.getBoolean("arjdbc.postgresql.iterval.raw");

    public static boolean useRawIntervalType() {
        return rawIntervalType;
    }

    public static void setRawIntervalType(boolean rawInterval) {
        PostgreSQLRubyJdbcConnection.rawIntervalType = rawInterval;
    }

}
