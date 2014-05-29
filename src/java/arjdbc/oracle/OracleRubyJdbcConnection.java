/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2014 Karol Bucek <self@kares.org>
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
package arjdbc.oracle;

import arjdbc.jdbc.Callable;
import arjdbc.jdbc.RubyJdbcConnection;
import arjdbc.util.CallResultSet;

import java.io.IOException;
import java.io.Reader;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
public class OracleRubyJdbcConnection extends RubyJdbcConnection {
    private static final long serialVersionUID = -6469731781108431512L;

    public OracleRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createOracleJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("OracleJdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(OracleRubyJdbcConnection.class);
        return clazz;
    }

    public static RubyClass load(final Ruby runtime) {
        RubyClass jdbcConnection = getJdbcConnectionClass(runtime);
        return createOracleJdbcConnectionClass(runtime, jdbcConnection);
    }

    protected static ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new OracleRubyJdbcConnection(runtime, klass);
        }
    };

    @JRubyMethod(name = "next_sequence_value", required = 1)
    public IRubyObject next_sequence_value(final ThreadContext context,
        final IRubyObject sequence) throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null; ResultSet valSet = null;
                try {
                    statement = connection.createStatement();
                    valSet = statement.executeQuery("SELECT "+ sequence +".NEXTVAL id FROM dual");
                    if ( ! valSet.next() ) return context.runtime.getNil();
                    return context.runtime.newFixnum( valSet.getLong(1) );
                }
                catch (final SQLException e) {
                    debugMessage(context, "failed to get " + sequence + ".NEXTVAL : " + e.getMessage());
                    throw e;
                }
                finally { close(valSet); close(statement); }
            }
        });
    }

    @JRubyMethod(name = "execute_insert_returning", required = 2)
    public IRubyObject execute_insert_returning(final ThreadContext context,
        final IRubyObject sql, final IRubyObject binds) throws SQLException {
        final String query = sql.convertToString().getUnicodeValue();
        final int outType = Types.VARCHAR;
        if ( binds == null || binds.isNil() ) { // no prepared statements
            return executePreparedCall(context, query, Collections.EMPTY_LIST, outType);
        }
        else { // allow prepared statements with empty binds parameters
            return executePreparedCall(context, query, (List) binds, outType);
        }
    }

    private IRubyObject executePreparedCall(final ThreadContext context, final String query,
        final List<?> binds, final int outType) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                CallableStatement statement = null;
                final int outIndex = binds.size() + 1;
                try {
                    statement = connection.prepareCall("{call " + query + " }");
                    setStatementParameters(context, connection, statement, binds);
                    statement.registerOutParameter(outIndex, outType);
                    statement.executeUpdate();
                    ResultSet resultSet = new CallResultSet(statement);
                    return jdbcToRuby(context, context.getRuntime(), outIndex, outType, resultSet);
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                }
                finally { close(statement); }
            }
        });
    }

    protected static final boolean generatedKeys;
    static {
        final String genKeys = System.getProperty("arjdbc.oracle.generated_keys");
        if ( genKeys == null ) {
            generatedKeys = true; // by default
        }
        else {
            generatedKeys = Boolean.parseBoolean(genKeys);
        }
    }

    @Override
    protected IRubyObject mapGeneratedKeys(
        final Ruby runtime, final Connection connection,
        final Statement statement, final Boolean singleResult)
        throws SQLException {
        if ( generatedKeys ) {
            return super.mapGeneratedKeys(runtime, connection, statement, singleResult);
        }
        return null; // disabled using -Darjdbc.oracle.generated_keys=false
    }

    private static final boolean returnRowID = Boolean.getBoolean("arjdbc.oracle.generated_keys.rowid");

    @Override // NOTE: Invalid column type:
    // getLong not implemented for class oracle.jdbc.driver.T4CRowidAccessor
    protected IRubyObject mapGeneratedKey(final Ruby runtime, final ResultSet genKeys)
        throws SQLException {
        // NOTE: it's likely a ROWID which we do not care about :
        final String value = genKeys.getString(1); // "AAAsOjAAFAAABUlAAA"
        if ( isPositiveInteger(value) ) {
            return runtime.newFixnum( Long.parseLong(value) );
        }
        else {
            return returnRowID ? runtime.newString(value) : runtime.getNil();
        }
    }

    private static boolean isPositiveInteger(final String value) {
        for ( int i = 0; i < value.length(); i++ ) {
            if ( ! Character.isDigit(value.charAt(i)) ) return false;
        }
        return true;
    }

    @Override // resultSet.wasNull() might be falsy for '' treated as null
    protected IRubyObject stringToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final String value = resultSet.getString(column);
        if ( value == null ) return runtime.getNil();
        return RubyString.newUnicodeString(runtime, value);
    }

    @Override
    protected IRubyObject readerToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException, IOException {
        final Reader reader = resultSet.getCharacterStream(column);
        try {
            if ( resultSet.wasNull() ) return RubyString.newEmptyString(runtime);

            final int bufSize = streamBufferSize;
            final StringBuilder string = new StringBuilder(bufSize);

            final char[] buf = new char[ bufSize / 2 ];
            for (int len = reader.read(buf); len != -1; len = reader.read(buf)) {
                string.append(buf, 0, len);
            }

            return RubyString.newUnicodeString(runtime, string.toString());
        }
        finally { if ( reader != null ) reader.close(); }
    }

    @Override // booleans are emulated can not setNull(index, Types.BOOLEAN)
    protected void setBooleanParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final Object value,
        final IRubyObject column, final int type) throws SQLException {
        if ( value instanceof IRubyObject ) {
            setBooleanParameter(context, connection, statement, index, (IRubyObject) value, column, type);
        }
        else {
            if ( value == null ) statement.setNull(index, Types.TINYINT);
            else {
                statement.setBoolean(index, ((Boolean) value).booleanValue());
            }
        }
    }

    @Override // booleans are emulated can not setNull(index, Types.BOOLEAN)
    protected void setBooleanParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject column, final int type) throws SQLException {
        if ( value.isNil() ) statement.setNull(index, Types.TINYINT);
        else {
            statement.setBoolean(index, value.isTrue());
        }
    }

    /**
     * Oracle needs this override to reconstruct NUMBER which is different
     * from NUMBER(x) or NUMBER(x,y).
     */
    @Override
    protected String typeFromResultSet(final ResultSet resultSet) throws SQLException {
        int precision = intFromResultSet(resultSet, COLUMN_SIZE);
        int scale = intFromResultSet(resultSet, DECIMAL_DIGITS);

        // According to http://forums.oracle.com/forums/thread.jspa?threadID=658646
        // Unadorned NUMBER reports scale == null, so we look for that here.
        if ( scale < 0 && resultSet.getInt(DATA_TYPE) == java.sql.Types.DECIMAL ) {
            precision = -1;
        }

        final String type = resultSet.getString(TYPE_NAME);
        return formatTypeWithPrecisionAndScale(type, precision, scale);
    }

    @Override
    protected RubyArray mapTables(final Ruby runtime, final DatabaseMetaData metaData,
            final String catalog, final String schemaPattern, final String tablePattern,
            final ResultSet tablesSet) throws SQLException {
        final List<IRubyObject> tables = new ArrayList<IRubyObject>(32);
        while ( tablesSet.next() ) {
            String name = tablesSet.getString(TABLES_TABLE_NAME);
            name = caseConvertIdentifierForRails(metaData, name);
            // Handle stupid Oracle 10g RecycleBin feature
            if ( name.startsWith("bin$") ) continue;
            tables.add(RubyString.newUnicodeString(runtime, name));
        }
        return runtime.newArray(tables);
    }

    // storesMixedCaseIdentifiers() return false;
    // storesLowerCaseIdentifiers() return false;
    // storesUpperCaseIdentifiers() return true;

    @Override
    protected String caseConvertIdentifierForRails(final Connection connection, final String value)
        throws SQLException {
        return value == null ? null : value.toLowerCase();
    }

    @Override
    protected String caseConvertIdentifierForJdbc(final Connection connection, final String value)
        throws SQLException {
        return value == null ? null : value.toUpperCase();
    }

}
