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

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;

import arjdbc.jdbc.SQLBlock;
import org.jruby.Ruby;
import org.jruby.RubyBigDecimal;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyNil;
import org.jruby.RubyString;
import org.jruby.RubyTime;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import arjdbc.jdbc.RubyJdbcConnection;

/**
 *
 * @author nicksieger
 */
public class MySQLRubyJdbcConnection extends RubyJdbcConnection {
    private boolean timezoneUTC = false;

    protected MySQLRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);

        IRubyObject activeRecordBase = runtime.getModule("ActiveRecord").getConstant("Base");
        if (activeRecordBase.respondsTo("default_timezone")) {
            IRubyObject defaultTimezone = activeRecordBase.callMethod(runtime.getCurrentContext(), "default_timezone");

            if (defaultTimezone.toString().equals("utc")) {
                timezoneUTC = true;
            }
        }
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
        } else if (Types.DECIMAL == type) {
            return decimalToRuby(runtime, resultSet, resultSet.getBigDecimal(column));
        }
        return super.jdbcToRuby(runtime, column, type, resultSet);
    }

    @Override
    protected IRubyObject timestampToRuby(Ruby runtime, ResultSet resultSet, Timestamp time) 
            throws SQLException {
        if (time == null && resultSet.wasNull()) return runtime.getNil();

        DateTime dt = new DateTime(time);
        if (timezoneUTC) {
           dt = dt.withZoneRetainFields(DateTimeZone.UTC);
        }

        return RubyTime.newTime(runtime, dt);
    }

    protected IRubyObject decimalToRuby(Ruby runtime, ResultSet resultSet, BigDecimal decimal) 
            throws SQLException {
        if (decimal == null && resultSet.wasNull()) return runtime.getNil();

        return new RubyBigDecimal(runtime, decimal);
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
  protected IRubyObject indexes(final ThreadContext context, final String tableNameArg, String name, final String schemaNameArg) {
    return (IRubyObject) withConnectionAndRetry(context, new SQLBlock() {
      @Override
      public Object call(Connection connection) throws SQLException {
        Ruby runtime = context.getRuntime();
        DatabaseMetaData metadata = connection.getMetaData();
        String jdbcTableName = caseConvertIdentifierForJdbc(metadata, tableNameArg);
        String jdbcSchemaName = caseConvertIdentifierForJdbc(metadata, schemaNameArg);

        StringBuilder buffer = new StringBuilder("SHOW KEYS FROM ");
        if (jdbcSchemaName != null) buffer.append(jdbcSchemaName).append(".");
        buffer.append(jdbcTableName);
        buffer.append(" WHERE key_name != 'PRIMARY'");
        String query = buffer.toString();

        List<IRubyObject> indexes = new ArrayList<IRubyObject>();
        PreparedStatement stmt = null;
        ResultSet rs = null;

        try {
          stmt = connection.prepareStatement(query);
          rs = stmt.executeQuery();

          IRubyObject rubyTableName = RubyString.newUnicodeString(runtime, caseConvertIdentifierForJdbc(metadata, tableNameArg));
          RubyModule indexDefinitionClass = getConnectionAdapters(runtime).getClass("IndexDefinition");
          String currentKeyName = null;

          while (rs.next()) {
            String keyName = caseConvertIdentifierForRails(metadata, rs.getString("key_name"));

            if (!keyName.equals(currentKeyName)) {
              currentKeyName = keyName;

              boolean nonUnique = rs.getBoolean("non_unique");
              IRubyObject indexDefinition = indexDefinitionClass.callMethod(context, "new", new IRubyObject[]{
                rubyTableName,
                RubyString.newUnicodeString(runtime, keyName),
                runtime.newBoolean(!nonUnique),
                runtime.newArray(),
                runtime.newArray()
              });

              indexes.add(indexDefinition);
            }

            IRubyObject lastIndex = indexes.get(indexes.size() - 1);
            if (lastIndex != null) {
              String columnName = caseConvertIdentifierForRails(metadata, rs.getString("column_name"));
              int length = rs.getInt("sub_part");
              boolean lengthIsNull = rs.wasNull();

              lastIndex.callMethod(context, "columns").callMethod(context, "<<", RubyString.newUnicodeString(runtime, columnName));
              lastIndex.callMethod(context, "lengths").callMethod(context, "<<", lengthIsNull ? runtime.getNil() : runtime.newFixnum(length));
            }
          }

          return runtime.newArray(indexes);
        } finally {
          close(rs);
          close(stmt);
        }
      }
    });
  }
}
