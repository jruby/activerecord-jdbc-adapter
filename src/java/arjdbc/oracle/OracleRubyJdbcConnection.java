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
// NOTE: file contains code adapted from **oracle-enhanced** adapter, license follows
/*
Copyright (c) 2008-2011 Graham Jenkins, Michael Schoen, Raimonds Simanovskis

... LICENSING TERMS ARE THE VERY SAME AS ACTIVERECORD-JDBC-ADAPTER'S ABOVE ...
*/
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
import java.sql.ResultSetMetaData;
import java.sql.Statement;
import java.sql.Types;
import java.util.Collections;
import java.util.List;
import java.util.regex.Pattern;

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

    protected OracleRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createOracleJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).
            defineClassUnder("OracleJdbcConnection", jdbcConnection, ORACLE_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(OracleRubyJdbcConnection.class);
        return clazz;
    }

    private static ObjectAllocator ORACLE_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new OracleRubyJdbcConnection(runtime, klass);
        }
    };

    @JRubyMethod(name = "next_sequence_value", required = 1)
    public IRubyObject next_sequence_value(final ThreadContext context, final IRubyObject sequence) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null; ResultSet value = null;
                try {
                    statement = connection.createStatement();
                    value = statement.executeQuery("SELECT "+ sequence +".NEXTVAL id FROM dual");
                    if ( ! value.next() ) return context.getRuntime().getNil();
                    return context.getRuntime().newFixnum( value.getLong(1) );
                }
                catch (final SQLException e) {
                    debugMessage(context, "failed to get " + sequence + ".NEXTVAL : " + e.getMessage());
                    throw e;
                }
                finally { close(value); close(statement); }
            }
        });
    }

    @JRubyMethod(name = "execute_insert_returning", required = 2)
    public IRubyObject execute_insert_returning(final ThreadContext context,
        final IRubyObject sql, final IRubyObject binds) {
        final String query = sql.convertToString().getUnicodeValue();
        final int outType = Types.VARCHAR;
        if ( binds == null || binds.isNil() ) { // no prepared statements
            return executePreparedCall(context, query, Collections.EMPTY_LIST, outType);
        }
        // allow prepared statements with empty binds parameters
        return executePreparedCall(context, query, (List) binds, outType);
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
        final RubyArray tables = RubyArray.newArray(runtime, 32);
        while ( tablesSet.next() ) {
            String name = tablesSet.getString(TABLES_TABLE_NAME);
            name = caseConvertIdentifierForRails(metaData, name);
            // Handle stupid Oracle 10g RecycleBin feature
            if ( name.startsWith("bin$") ) continue;
            tables.append(RubyString.newUnicodeString(runtime, name));
        }
        return tables;
    }

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
            if (columnType == Types.NUMERIC) {
                // avoid extracting all NUMBER columns as BigDecimal :
                if (resultMetaData.getScale(i) == 0) {
                    final int prec = resultMetaData.getPrecision(i);
                    if ( prec < 10 ) { // fits into int
                        columnType = Types.INTEGER;
                    }
                    else if ( prec < 19 ) { // fits into long
                        columnType = Types.BIGINT;
                    }
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
    protected String caseConvertIdentifierForRails(final Connection connection, final String value)
        throws SQLException {
        return value == null ? null : value.toLowerCase();
    }

    @Override
    protected String caseConvertIdentifierForJdbc(final Connection connection, final String value)
        throws SQLException {
        return value == null ? null : value.toUpperCase();
    }

    // based on OracleEnhanced's Ruby connection.describe
    @JRubyMethod(name = "describe", required = 1)
    public IRubyObject describe(final ThreadContext context, final IRubyObject name) {
        final RubyArray desc = describe(context, name.toString(), null);
        return desc == null ? context.nil : desc; // TODO raise instead of nil
    }

    @JRubyMethod(name = "describe", required = 2)
    public IRubyObject describe(final ThreadContext context, final IRubyObject name, final IRubyObject owner) {
        final RubyArray desc = describe(context, name.toString(), owner.isNil() ? null : owner.toString());
        return desc == null ? context.nil : desc; // TODO raise instead of nil
    }

    private RubyArray describe(final ThreadContext context, final String name, final String owner) {
        final String dbLink; String defaultOwner, theName = name; int delim;
        if ( ( delim = theName.indexOf('@') ) > 0 ) {
            dbLink = theName.substring(delim).toUpperCase(); // '@DBLINK'
            theName = theName.substring(0, delim);
            defaultOwner = null; // will SELECT username FROM all_dbLinks ...
        }
        else {
            dbLink = ""; defaultOwner = owner; // config[:username] || meta_data.user_name
        }

        theName = isValidTableName(theName) ? theName.toUpperCase() : unquoteTableName(theName);

        final String tableName; final String tableOwner;
        if ( ( delim = theName.indexOf('.') ) > 0 ) {
            tableOwner = theName.substring(0, delim);
            tableName = theName.substring(delim + 1);
        }
        else {
            tableName = theName;
            tableOwner = (defaultOwner == null && dbLink.length() > 0) ? selectOwner(context, dbLink) : defaultOwner;
        }

        return withConnection(context, new Callable<RubyArray>() {
            public RubyArray call(final Connection connection) throws SQLException {
                String owner = tableOwner == null ? connection.getMetaData().getUserName() : tableOwner;
                final String sql =
                "SELECT owner, table_name, 'TABLE' name_type" +
                " FROM all_tables" + dbLink +
                " WHERE owner = '" + owner + "' AND table_name = '" + tableName + "'" +
                " UNION ALL " +
                "SELECT owner, view_name table_name, 'VIEW' name_type" +
                " FROM all_views" + dbLink +
                " WHERE owner = '" + owner + "' AND view_name = '" + tableName + "'" +
                " UNION ALL " +
                "SELECT table_owner, DECODE(db_link, NULL, table_name, table_name||'@'||db_link), 'SYNONYM' name_type" +
                " FROM all_synonyms" + dbLink +
                " WHERE owner = '" + owner + "' AND synonym_name = '" + tableName + "'" +
                " UNION ALL " +
                "SELECT table_owner, DECODE(db_link, NULL, table_name, table_name||'@'||db_link), 'SYNONYM' name_type" +
                " FROM all_synonyms" + dbLink +
                " WHERE owner = 'PUBLIC' AND synonym_name = '" + tableName + "'" ;

                Statement statement = null; ResultSet result = null;
                try {
                    statement = connection.createStatement();
                    result = statement.executeQuery(sql);

                    if ( ! result.next() ) return null; // NOTE: should raise

                    owner = result.getString("owner");
                    final String table_name = result.getString("table_name");
                    final String name_type = result.getString("name_type");

                    if ( "SYNONYM".equals(name_type) ) {
                        final StringBuilder name = new StringBuilder();
                        if ( owner != null && owner.length() > 0 ) {
                            name.append(owner).append('.');
                        }
                        name.append(table_name);
                        if ( dbLink != null ) name.append(dbLink);
                        return describe(context, name.toString(), owner);
                    }

                    final RubyArray arr = RubyArray.newArray(context.runtime, 3);
                    arr.append( context.runtime.newString(owner) );
                    arr.append( context.runtime.newString(table_name) );
                    if ( dbLink != null ) arr.append( context.runtime.newString(dbLink) );
                    return arr;
                }
                catch (final SQLException e) {
                    debugMessage(context, "failed to describe '" + name + "' : " + e.getMessage());
                    throw e;
                }
                finally { close(result); close(statement); }
            }
        });
    }

    private String selectOwner(final ThreadContext context, final String dbLink) {
        return withConnection(context, new Callable<String>() {
            public String call(final Connection connection) throws SQLException {
                Statement statement = null; ResultSet result = null;
                final String sql = "SELECT username FROM all_db_links WHERE db_link = '" + dbLink + "'";
                try {
                    statement = connection.createStatement();
                    result = statement.executeQuery(sql);
                    // if ( ! result.next() ) return null;
                    return result.getString(1);
                }
                catch (final SQLException e) {
                    debugMessage(context, "\"" + sql + "\" failed : " + e.getMessage());
                    throw e;
                }
                finally { close(result); close(statement); }
            }
        });
    }

    private static final Pattern VALID_TABLE_NAME;
    static {
        final String NONQUOTED_OBJECT_NAME = "[A-Za-z][A-z0-9$#]{0,29}";
        final String NONQUOTED_DATABASE_LINK = "[A-Za-z][A-z0-9$#\\.@]{0,127}";
        VALID_TABLE_NAME = Pattern.compile(
        "\\A(?:" + NONQUOTED_OBJECT_NAME + "\\.)?" + NONQUOTED_OBJECT_NAME + "(?:@" + NONQUOTED_DATABASE_LINK + ")?\\Z");
    }

    private static boolean isValidTableName(final String name) {
        return VALID_TABLE_NAME.matcher(name).matches();
    }

    private static String unquoteTableName(String name) {
        name = name.trim();
        final int len = name.length();
        if (len > 0 && name.charAt(0) == '"' && name.charAt(len - 1) == '"') {
            return name.substring(1, len - 1);
        }
        return name;
    }

}
