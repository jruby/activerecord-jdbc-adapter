/*
 * The MIT License
 *
 * Copyright 2015 Karol Bucek.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package arjdbc.firebird;

import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.PreparedStatement;
import java.sql.ResultSetMetaData;
import java.sql.Types;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyString;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * @author kares
 */
public class FirebirdRubyJdbcConnection extends RubyJdbcConnection {

    protected FirebirdRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createFirebirdJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).
            defineClassUnder("FirebirdJdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(FirebirdRubyJdbcConnection.class);
        return clazz;
    }

    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new FirebirdRubyJdbcConnection(runtime, klass);
        }
    };

    @Override // resultSet.wasNull() might be falsy for '' treated as null
    protected IRubyObject stringToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final String value = resultSet.getString(column);
        if ( value == null ) return runtime.getNil();
        return RubyString.newUnicodeString(runtime, value);
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
            if ( value == null ) statement.setNull(index, Types.CHAR);
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
        if ( value.isNil() ) statement.setNull(index, Types.CHAR);
        else {
            statement.setBoolean(index, value.isTrue());
        }
    }

    protected IRubyObject jdbcToRuby(
        final ThreadContext context, final Ruby runtime,
        final int column, final int type, final ResultSet resultSet)
        throws SQLException {

        switch (type) {
        case SMALL_CHAR_1:
            return smallChar1ToRuby(runtime, resultSet, column);
        case SMALL_CHAR_2:
            return smallChar2ToRuby(runtime, resultSet, column);
        }
        return super.jdbcToRuby(context, runtime, column, type, resultSet);
    }

    private static IRubyObject smallChar1ToRuby(
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        String value = resultSet.getString(column);
        if ( value == null ) return runtime.getNil();
        if ( value.length() > 1 && value.charAt(1) == ' ' ) {
            value = value.substring(0, 1);
        }
        return RubyString.newUnicodeString(runtime, value);
    }

    private static IRubyObject smallChar2ToRuby(
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        String value = resultSet.getString(column);
        if ( value == null ) return runtime.getNil();
        if ( value.length() > 2 && value.charAt(2) == ' ' ) {
            value = value.substring(0, 2);
        }
        return RubyString.newUnicodeString(runtime, value);
    }

    private final static int SMALL_CHAR_1 = 31431001;
    private final static int SMALL_CHAR_2 = 31431002;

    @Override
    protected ColumnData[] extractColumns(final Ruby runtime,
        final Connection connection, final ResultSet resultSet,
        final boolean downCase) throws SQLException {

        final ResultSetMetaData resultMetaData = resultSet.getMetaData();

        final int columnCount = resultMetaData.getColumnCount();
        final ColumnData[] columns = new ColumnData[columnCount];

        for ( int i = 1; i <= columnCount; i++ ) { // metadata is one-based
            String name = resultMetaData.getColumnLabel(i);
            if ( downCase ) {
                name = name.toLowerCase();
            } else {
                name = caseConvertIdentifierForRails(connection, name);
            }
            final RubyString columnName = RubyString.newUnicodeString(runtime, name);

            int columnType = resultMetaData.getColumnType(i);
            if (columnType == Types.CHAR) {
                // CHAR(1) 'aligned' by JayBird to "1  "
                final int prec = resultMetaData.getPrecision(i);
                if ( prec == 1 ) {
                    columnType = SMALL_CHAR_1;
                }
                else if ( prec == 2 ) {
                    columnType = SMALL_CHAR_2;
                }
            }

            columns[i - 1] = new ColumnData(columnName, columnType, i);
        }

        return columns;
    }

    // storesMixedCaseIdentifiers() return false;
    // storesLowerCaseIdentifiers() return false;
    // storesUpperCaseIdentifiers() return true;

    @Override
    protected String caseConvertIdentifierForRails(final Connection connection, final String value) {
        return value == null ? null : value.toLowerCase();
    }

    @Override
    protected String caseConvertIdentifierForJdbc(final Connection connection, final String value) {
        return value == null ? null : value.toUpperCase();
    }

}
