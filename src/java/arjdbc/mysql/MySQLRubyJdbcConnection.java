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
package arjdbc.mysql;

import arjdbc.jdbc.RubyJdbcConnection;
import arjdbc.jdbc.SQLBlock;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
public class MySQLRubyJdbcConnection extends RubyJdbcConnection {

    protected MySQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    @Override
    protected boolean genericExecute(Statement stmt, String query) throws SQLException {
        return stmt.execute(query, Statement.RETURN_GENERATED_KEYS);
    }

    @Override
    protected IRubyObject unmarshalKeysOrUpdateCount(ThreadContext context, Connection c, Statement stmt) throws SQLException {
        IRubyObject key = unmarshal_id_result(context.getRuntime(), stmt.getGeneratedKeys());
        if (key.isNil()) {
            return context.getRuntime().newFixnum(stmt.getUpdateCount());
        }
        return key;
    }

    @Override
    protected IRubyObject jdbcToRuby(Ruby runtime, int column, int type, ResultSet resultSet)
            throws SQLException {
        if (Types.BOOLEAN == type || Types.BIT == type) {
            return integerToRuby(runtime, resultSet, resultSet.getBoolean(column) ? 1 : 0);
        }
        return super.jdbcToRuby(runtime, column, type, resultSet);
    }

    public static RubyClass createMySQLJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = RubyJdbcConnection.getConnectionAdapters(runtime).defineClassUnder("MySQLJdbcConnection",
                jdbcConnection, MYSQL_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(MySQLRubyJdbcConnection.class);

        return clazz;
    }
    private static ObjectAllocator MYSQL_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new MySQLRubyJdbcConnection(runtime, klass);
        }
    };

    @Override
    protected IRubyObject indexes(final ThreadContext context, final String tableName, final String name, final String schemaName) {
        return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
            @Override
            public Object call(Connection connection) throws SQLException {
                final Ruby runtime = context.getRuntime();
                final RubyModule indexDefinition = getConnectionAdapters(runtime).getClass("IndexDefinition");
                final DatabaseMetaData metaData = connection.getMetaData();
                final String jdbcTableName = caseConvertIdentifierForJdbc(metaData, tableName);
                final String jdbcSchemaName = caseConvertIdentifierForJdbc(metaData, schemaName);
                final IRubyObject rubyTableName = RubyString.newUnicodeString(
                    runtime, caseConvertIdentifierForJdbc(metaData, tableName)
                );
                
                StringBuilder buffer = new StringBuilder("SHOW KEYS FROM ");
                if (jdbcSchemaName != null) {
                    buffer.append(jdbcSchemaName).append(".");
                }
                buffer.append(jdbcTableName);
                buffer.append(" WHERE key_name != 'PRIMARY'");
                
                final String query = buffer.toString();
                final List<IRubyObject> indexes = new ArrayList<IRubyObject>();
                PreparedStatement statement = null;
                ResultSet keySet = null;

                try {
                    statement = connection.prepareStatement(query);
                    keySet = statement.executeQuery();
                    
                    String currentKeyName = null;

                    while ( keySet.next() ) {
                        final String keyName = caseConvertIdentifierForRails(metaData, keySet.getString("key_name"));

                        if ( ! keyName.equals(currentKeyName) ) {
                            currentKeyName = keyName;

                            final boolean nonUnique = keySet.getBoolean("non_unique");
                            
                            IRubyObject[] args = new IRubyObject[] {
                                rubyTableName, // table_name
                                RubyString.newUnicodeString(runtime, keyName), // index_name
                                runtime.newBoolean( ! nonUnique ), // unique
                                runtime.newArray(), // [] for column names, we'll add to that in just a bit
                                runtime.newArray() // lengths
                            };

                            indexes.add( indexDefinition.callMethod(context, "new", args) ); // IndexDefinition.new
                        }

                        IRubyObject lastIndexDef = indexes.isEmpty() ? null : indexes.get(indexes.size() - 1);
                        if (lastIndexDef != null) {
                            final String columnName = caseConvertIdentifierForRails(metaData, keySet.getString("column_name"));
                            final int length = keySet.getInt("sub_part");
                            final boolean nullLength = keySet.wasNull();

                            lastIndexDef.callMethod(context, "columns").callMethod(context, 
                                    "<<", RubyString.newUnicodeString(runtime, columnName));
                            lastIndexDef.callMethod(context, "lengths").callMethod(context, 
                                    "<<", nullLength ? runtime.getNil() : runtime.newFixnum(length));
                        }
                    }
                    
                    return runtime.newArray(indexes);
                    
                } finally {
                    close(keySet);
                    close(statement);
                }
            }
        });
    }
}
