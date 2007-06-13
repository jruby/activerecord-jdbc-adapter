/***** BEGIN LICENSE BLOCK *****
 * Version: CPL 1.0/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Common Public
 * License Version 1.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.eclipse.org/legal/cpl-v10.html
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * Copyright (C) 2007 Ola Bini <ola@ologix.com>
 * 
 * Alternatively, the contents of this file may be used under the terms of
 * either of the GNU General Public License Version 2 or later (the "GPL"),
 * or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the CPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the CPL, the GPL or the LGPL.
 ***** END LICENSE BLOCK *****/
import java.io.IOException;
import java.io.Reader;
import java.io.InputStream;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSetMetaData;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Iterator;
import java.util.HashMap;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBigDecimal;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyModule;
import org.jruby.RubyNumeric;
import org.jruby.RubyString;
import org.jruby.javasupport.JavaObject;
import org.jruby.runtime.Block;
import org.jruby.runtime.CallbackFactory;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.BasicLibraryService;
import org.jruby.util.ByteList;

public class JdbcAdapterInternalService implements BasicLibraryService {
    public boolean basicLoad(final Ruby runtime) throws IOException {
        RubyClass cJdbcConn = ((RubyModule)(runtime.getModule("ActiveRecord").getConstant("ConnectionAdapters"))).
            defineClassUnder("JdbcConnection",runtime.getObject(),runtime.getObject().getAllocator());

        CallbackFactory cf = runtime.callbackFactory(JdbcAdapterInternalService.class);
        cJdbcConn.defineMethod("unmarshal_result",cf.getSingletonMethod("unmarshal_result", IRubyObject.class));
        cJdbcConn.defineFastMethod("set_connection",cf.getFastSingletonMethod("set_connection", IRubyObject.class));
        cJdbcConn.defineFastMethod("execute_update",cf.getFastSingletonMethod("execute_update", IRubyObject.class));
        cJdbcConn.defineFastMethod("execute_query",cf.getFastOptSingletonMethod("execute_query")); 
        cJdbcConn.defineFastMethod("execute_insert",cf.getFastSingletonMethod("execute_insert", IRubyObject.class));
        cJdbcConn.defineFastMethod("execute_id_insert",cf.getFastSingletonMethod("execute_id_insert", IRubyObject.class, IRubyObject.class));
        cJdbcConn.defineFastMethod("primary_keys",cf.getFastSingletonMethod("primary_keys", IRubyObject.class));
        cJdbcConn.defineFastMethod("set_native_database_types",cf.getFastSingletonMethod("set_native_database_types"));
        cJdbcConn.defineFastMethod("native_database_types",cf.getFastSingletonMethod("native_database_types"));
        cJdbcConn.defineFastMethod("begin",cf.getFastSingletonMethod("begin"));
        cJdbcConn.defineFastMethod("commit",cf.getFastSingletonMethod("commit"));
        cJdbcConn.defineFastMethod("rollback",cf.getFastSingletonMethod("rollback"));
        cJdbcConn.defineFastMethod("database_name",cf.getFastSingletonMethod("database_name"));
        cJdbcConn.defineFastMethod("columns",cf.getFastOptSingletonMethod("columns"));
        cJdbcConn.defineFastMethod("tables",cf.getFastOptSingletonMethod("tables"));

        RubyModule jdbcSpec = runtime.getOrCreateModule("JdbcSpec");
        JDBCMySQLSpec.load(runtime, jdbcSpec);
        JDBCDerbySpec.load(runtime, jdbcSpec);

        return true;
    }

    private static ResultSet intoResultSet(IRubyObject inp) {
        return (ResultSet)((inp instanceof JavaObject ? ((JavaObject)inp) : (((JavaObject)(inp.getInstanceVariable("@java_object"))))).getValue());
    }   

    public static IRubyObject set_connection(IRubyObject recv, IRubyObject conn) {
        Connection c = (Connection)recv.dataGetStruct();
        if(c != null) {
            try {
                c.close();
            } catch(Exception e) {}
        }
        recv.setInstanceVariable("@connection",conn);
        c = (Connection)(((JavaObject)conn.getInstanceVariable("@java_object")).getValue());
        recv.dataWrapStruct(c);
        return recv;
    }

    public static IRubyObject tables(IRubyObject recv, IRubyObject[] args) throws SQLException, IOException {
        Ruby runtime = recv.getRuntime();
        String catalog = null, schemapat = null, tablepat = null;
        String[] types = new String[]{"TABLE"};
        if (args != null) {
            if (args.length > 0) {
                catalog = convertToStringOrNull(args[0]);
            }
            if (args.length > 1) {
                schemapat = convertToStringOrNull(args[1]);
            }
            if (args.length > 2) {
                tablepat = convertToStringOrNull(args[2]);
            }
            if (args.length > 3) {
                IRubyObject typearr = args[3];
                if (typearr instanceof RubyArray) {
                    IRubyObject[] arr = ((RubyArray) typearr).toJavaArray();
                    types = new String[arr.length];
                    for (int i = 0; i < types.length; i++) {
                        types[i] = arr[i].toString();
                    }
                } else {
                    types = new String[] {types.toString()};
                }
            }
        }
        while (true) {
            Connection c = (Connection) recv.dataGetStruct();
            ResultSet rs = null;
            try {
                rs = c.getMetaData().getTables(catalog, schemapat, tablepat, types);
                List arr = new ArrayList();
                while (rs.next()) {
                    arr.add(runtime.newString(rs.getString(3).toLowerCase()));
                }
                return runtime.newArray(arr);
            } catch (SQLException e) {
                if(c.isClosed()) {
                    recv.callMethod(recv.getRuntime().getCurrentContext(),"reconnect!");
                    continue;
                }
                throw e;
            } finally {
                try {
                    rs.close();
                } catch(Exception e) {}
            }

        }
    }

    /*
      # The hacks in this method is needed because of a bug in Rails. Check
      # out type_to_sql in schema_statements.rb and see if you can see it... =)
    */
    public static IRubyObject native_database_types(IRubyObject recv) {
        RubyHash tps = (RubyHash)recv.getInstanceVariable("@tps");
        Map val = new HashMap();
        Ruby runtime = recv.getRuntime();
        IRubyObject nameSym = runtime.newSymbol("name");
        for(Iterator iter = tps.directEntrySet().iterator();iter.hasNext();) {
            Map.Entry me = (Map.Entry)iter.next();
            IRubyObject v = (IRubyObject)me.getValue();
            if(v instanceof RubyHash) {
                RubyHash v2 = (RubyHash)(v.dup());
                v2.put(nameSym, ((IRubyObject)(v2.fastARef(nameSym))).dup());
                val.put(me.getKey(), v2);
            } else {
                val.put(me.getKey(), ((IRubyObject)v).dup());
            }
        }
        return RubyHash.newHash(runtime, val, runtime.getNil());
    }    

    public static IRubyObject set_native_database_types(IRubyObject recv) throws SQLException, IOException {
        Ruby runtime = recv.getRuntime();
        ThreadContext ctx = runtime.getCurrentContext();
        IRubyObject types = unmarshal_result_downcase(recv, ((Connection)recv.dataGetStruct()).getMetaData().getTypeInfo());
        recv.setInstanceVariable("@native_types", 
                                 ((RubyModule)(runtime.getModule("ActiveRecord").getConstant("ConnectionAdapters"))).
                                 getConstant("JdbcTypeConverter").callMethod(ctx,"new", types).
                                 callMethod(ctx, "choose_best_types"));
        return runtime.getNil();
    }

    public static IRubyObject database_name(IRubyObject recv) throws SQLException {
        String name = ((Connection)recv.dataGetStruct()).getCatalog();
        if(null == name) {
            name = ((Connection)recv.dataGetStruct()).getMetaData().getUserName();
            if(null == name) {
                name = "db1";
            }
        }
        return recv.getRuntime().newString(name);
    }

    public static IRubyObject begin(IRubyObject recv) throws SQLException {
        ((Connection)recv.dataGetStruct()).setAutoCommit(false);
        return recv.getRuntime().getNil();
    }

    public static IRubyObject commit(IRubyObject recv) throws SQLException {
        try {
            ((Connection)recv.dataGetStruct()).commit();
            return recv.getRuntime().getNil();
        } finally {
            ((Connection)recv.dataGetStruct()).setAutoCommit(true);
        }
    }

    public static IRubyObject rollback(IRubyObject recv) throws SQLException {
        try {
            ((Connection)recv.dataGetStruct()).rollback();
            return recv.getRuntime().getNil();
        } finally {
            ((Connection)recv.dataGetStruct()).setAutoCommit(true);
        }
    }

    public static IRubyObject columns(IRubyObject recv, IRubyObject[] args) throws SQLException, IOException {
        String table_name = args[0].convertToString().getUnicodeValue();
        while(true) {
            Connection c = (Connection)recv.dataGetStruct();
            try {
                DatabaseMetaData metadata = c.getMetaData();
                if(metadata.storesUpperCaseIdentifiers()) {
                    table_name = table_name.toUpperCase();
                } else if(metadata.storesLowerCaseIdentifiers()) {
                    table_name = table_name.toLowerCase();
                }
                ResultSet results = metadata.getColumns(null,null,table_name,null);
                return unmarshal_columns(recv, metadata, results);
            } catch(SQLException e) {
                if(c.isClosed()) {
                    recv.callMethod(recv.getRuntime().getCurrentContext(),"reconnect!");
                    continue;
                }
                throw e;
            }
        }    
    }

    private static final java.util.regex.Pattern HAS_SMALL = java.util.regex.Pattern.compile("[a-z]");
    private static final java.util.regex.Pattern HAS_LARGE = java.util.regex.Pattern.compile("[A-Z]");
    private static IRubyObject unmarshal_columns(IRubyObject recv, DatabaseMetaData metadata, ResultSet rs) throws SQLException, IOException {
        try {
            List columns = new ArrayList();
            boolean isDerby = metadata.getClass().getName().indexOf("derby") != -1;
            Ruby runtime = recv.getRuntime();
            ThreadContext ctx = runtime.getCurrentContext();

            RubyHash tps = ((RubyHash)(recv.callMethod(ctx, "adapter").callMethod(ctx,"native_database_types")));

            IRubyObject jdbcCol = ((RubyModule)(runtime.getModule("ActiveRecord").getConstant("ConnectionAdapters"))).getConstant("JdbcColumn");

            while(rs.next()) {
                String column_name = rs.getString(4);
                if(metadata.storesUpperCaseIdentifiers() && !HAS_SMALL.matcher(column_name).find()) {
                    column_name = column_name.toLowerCase();
                }

                String prec = rs.getString(7);
                String scal = rs.getString(9);
                int precision = -1;
                int scale = -1;
                if(prec != null) {
                    precision = Integer.parseInt(prec);
                    if(scal != null) {
                        scale = Integer.parseInt(scal);
                    }
                }
                String type = rs.getString(6);
                if(prec != null && precision > 0) {
                    type += "(" + precision;
                    if(scal != null && scale > 0) {
                        type += "," + scale;
                    }
                    type += ")";
                }
                String def = rs.getString(13);
                IRubyObject _def;
                if(def == null) {
                    _def = runtime.getNil();
                } else {
                    if(isDerby && def.length() > 0 && def.charAt(0) == '\'') {
                        def = def.substring(1, def.length()-1);
                    }
                    _def = runtime.newString(def);
                }

                IRubyObject c = jdbcCol.callMethod(ctx,"new", new IRubyObject[]{recv.getInstanceVariable("@config"), runtime.newString(column_name),
                                                                                _def, runtime.newString(type), 
                                                                                runtime.newBoolean(!rs.getString(18).equals("NO"))});
                columns.add(c);

                IRubyObject tp = (IRubyObject)tps.fastARef(c.callMethod(ctx,"type"));
                if(tp != null && !tp.isNil() && tp.callMethod(ctx,"[]",runtime.newSymbol("limit")).isNil()) {
                    c.callMethod(ctx,"limit=", runtime.getNil());
                    if(!c.callMethod(ctx,"type").equals(runtime.newSymbol("decimal"))) {
                        c.callMethod(ctx,"precision=", runtime.getNil());
                    }
                }
            }
            return runtime.newArray(columns);
        } finally {
            try {
                rs.close();
            } catch(Exception e) {}
        }
    }

    public static IRubyObject primary_keys(IRubyObject recv, IRubyObject _table_name) throws SQLException {
        Connection c = (Connection)recv.dataGetStruct();
        DatabaseMetaData metadata = c.getMetaData();
        String table_name = _table_name.toString();
        if(metadata.storesUpperCaseIdentifiers()) {
            table_name = table_name.toUpperCase();
        } else if(metadata.storesLowerCaseIdentifiers()) {
            table_name = table_name.toLowerCase();
        }
        ResultSet result_set = metadata.getPrimaryKeys(null,null,table_name);
        List keyNames = new ArrayList();
        Ruby runtime = recv.getRuntime();
        while(result_set.next()) {
            String s1 = result_set.getString(4);
            if(metadata.storesUpperCaseIdentifiers() && !HAS_SMALL.matcher(s1).find()) {
                s1 = s1.toLowerCase();
            }
            keyNames.add(runtime.newString(s1));
        }
        
        try {
            result_set.close();
        } catch(Exception e) {}

        return runtime.newArray(keyNames);
    }

    public static IRubyObject execute_id_insert(IRubyObject recv, IRubyObject sql, IRubyObject id) throws SQLException {
        Connection c = (Connection)recv.dataGetStruct();
        PreparedStatement ps = c.prepareStatement(sql.convertToString().getUnicodeValue());
        try {
            ps.setLong(1,RubyNumeric.fix2long(id));
            ps.executeUpdate();
        } finally {
            ps.close();
        }
        return id;
    }

    public static IRubyObject execute_update(IRubyObject recv, IRubyObject sql) throws SQLException {
        while(true) {
            Connection c = (Connection)recv.dataGetStruct();
            Statement stmt = null;
            try {
                stmt = c.createStatement();
                return recv.getRuntime().newFixnum(stmt.executeUpdate(sql.convertToString().getUnicodeValue()));
            } catch(SQLException e) {
                if(c.isClosed()) {
                    recv.callMethod(recv.getRuntime().getCurrentContext(),"reconnect!");
                    continue;
                }
                throw e;
            } finally {
                if(null != stmt) {
                    try {
                        stmt.close();
                    } catch(Exception e) {}
                }
            }
        }
    }

    public static IRubyObject execute_query(IRubyObject recv, IRubyObject[] args) throws SQLException, IOException {
        IRubyObject sql = args[0];
        int maxrows = 0;
        if(args.length > 1) {
            maxrows = RubyNumeric.fix2int(args[1]);
        }
        while(true) {
            Connection c = (Connection)recv.dataGetStruct();
            Statement stmt = null;
            try {
                stmt = c.createStatement();
                stmt.setMaxRows(0);
                return unmarshal_result(recv, stmt.executeQuery(sql.convertToString().getUnicodeValue()));
            } catch(SQLException e) {
                if(c.isClosed()) {
                    recv.callMethod(recv.getRuntime().getCurrentContext(),"reconnect!");
                    continue;
                }
                throw e;
            } finally {
                if(null != stmt) {
                    try {
                        stmt.close();
                    } catch(Exception e) {}
                }
            }
        }
    }

    public static IRubyObject execute_insert(IRubyObject recv, IRubyObject sql) throws SQLException {
        while(true) {
            Connection c = (Connection)recv.dataGetStruct();
            Statement stmt = null;
            try {
                stmt = c.createStatement();
                stmt.executeUpdate(sql.convertToString().getUnicodeValue(), Statement.RETURN_GENERATED_KEYS);
                return unmarshal_id_result(recv.getRuntime(), stmt.getGeneratedKeys());
            } catch(SQLException e) {
                if(c.isClosed()) {
                    recv.callMethod(recv.getRuntime().getCurrentContext(),"reconnect!");
                    continue;
                }
                throw e;
            } finally {
                if(null != stmt) {
                    try {
                        stmt.close();
                    } catch(Exception e) {}
                }
            }
        }
    }

    public static IRubyObject unmarshal_result_downcase(IRubyObject recv, ResultSet rs) throws SQLException, IOException {
        List results = new ArrayList();
        Ruby runtime = recv.getRuntime();
        try {
            ResultSetMetaData metadata = rs.getMetaData();
            int col_count = metadata.getColumnCount();
            IRubyObject[] col_names = new IRubyObject[col_count];
            int[] col_types = new int[col_count];
            int[] col_scale = new int[col_count];

            for(int i=0;i<col_count;i++) {
                col_names[i] = runtime.newString(metadata.getColumnName(i+1).toLowerCase());
                col_types[i] = metadata.getColumnType(i+1);
                col_scale[i] = metadata.getScale(i+1);
            }

            while(rs.next()) {
                RubyHash row = RubyHash.newHash(runtime);
                for(int i=0;i<col_count;i++) {
                    row.aset(col_names[i], jdbc_to_ruby(runtime, i+1, col_types[i], col_scale[i], rs));
                }
                results.add(row);
            }
        } finally {
            try {
                rs.close();
            } catch(Exception e) {}
        }
 
        return runtime.newArray(results);
    }

    public static IRubyObject unmarshal_result(IRubyObject recv, ResultSet rs) throws SQLException, IOException {
        Ruby runtime = recv.getRuntime();
        List results = new ArrayList();
        try {
            ResultSetMetaData metadata = rs.getMetaData();
            boolean storesUpper = rs.getStatement().getConnection().getMetaData().storesUpperCaseIdentifiers();
            int col_count = metadata.getColumnCount();
            IRubyObject[] col_names = new IRubyObject[col_count];
            int[] col_types = new int[col_count];
            int[] col_scale = new int[col_count];

            for(int i=0;i<col_count;i++) {
                String s1 = metadata.getColumnName(i+1);
                if(storesUpper && !HAS_SMALL.matcher(s1).find()) {
                    s1 = s1.toLowerCase();
                }
                col_names[i] = runtime.newString(s1);
                col_types[i] = metadata.getColumnType(i+1);
                col_scale[i] = metadata.getScale(i+1);
            }

            while(rs.next()) {
                RubyHash row = RubyHash.newHash(runtime);
                for(int i=0;i<col_count;i++) {
                    row.aset(col_names[i], jdbc_to_ruby(runtime, i+1, col_types[i], col_scale[i], rs));
                }
                results.add(row);
            }
        } finally {
            try {
                rs.close();
            } catch(Exception e) {}
        }
        return runtime.newArray(results);
    }

    public static IRubyObject unmarshal_result(IRubyObject recv, IRubyObject resultset, Block row_filter) throws SQLException, IOException {
        Ruby runtime = recv.getRuntime();
        ResultSet rs = intoResultSet(resultset);
        List results = new ArrayList();
        try {
            ResultSetMetaData metadata = rs.getMetaData();
            int col_count = metadata.getColumnCount();
            IRubyObject[] col_names = new IRubyObject[col_count];
            int[] col_types = new int[col_count];
            int[] col_scale = new int[col_count];

            for(int i=0;i<col_count;i++) {
                col_names[i] = runtime.newString(metadata.getColumnName(i+1));
                col_types[i] = metadata.getColumnType(i+1);
                col_scale[i] = metadata.getScale(i+1);
            }

            if(row_filter.isGiven()) {
                while(rs.next()) {
                    if(row_filter.yield(runtime.getCurrentContext(),resultset).isTrue()) {
                        RubyHash row = RubyHash.newHash(runtime);
                        for(int i=0;i<col_count;i++) {
                            row.aset(col_names[i], jdbc_to_ruby(runtime, i+1, col_types[i], col_scale[i], rs));
                        }
                        results.add(row);
                    }
                }
            } else {
                while(rs.next()) {
                    RubyHash row = RubyHash.newHash(runtime);
                    for(int i=0;i<col_count;i++) {
                        row.aset(col_names[i], jdbc_to_ruby(runtime, i+1, col_types[i], col_scale[i], rs));
                    }
                    results.add(row);
                }
            }

        } finally {
            try {
                rs.close();
            } catch(Exception e) {}
        }
 
        return runtime.newArray(results);
    }

    private static IRubyObject jdbc_to_ruby(Ruby runtime, int row, int type, int scale, ResultSet rs) throws SQLException, IOException {
        int n;
        switch(type) {
        case Types.BINARY:
        case Types.BLOB:
        case Types.LONGVARBINARY:
        case Types.VARBINARY:
            InputStream is = rs.getBinaryStream(row);
            if(is == null || rs.wasNull()) {
                return runtime.getNil();
            }
            ByteList str = new ByteList(2048);
            byte[] buf = new byte[2048];
            while((n = is.read(buf)) != -1) {
                str.append(buf, 0, n);
            }
            is.close();
            return runtime.newString(str);
        case Types.LONGVARCHAR:
        case Types.CLOB:
            Reader rss = rs.getCharacterStream(row);
            if(rss == null || rs.wasNull()) {
                return runtime.getNil();
            }
            StringBuffer str2 = new StringBuffer(2048);
            char[] cuf = new char[2048];
            while((n = rss.read(cuf)) != -1) {
                str2.append(cuf, 0, n);
            }
            rss.close();
            return RubyString.newUnicodeString(runtime, str2.toString());
        default:
            String vs = rs.getString(row);
            if(vs == null || rs.wasNull()) {
                return runtime.getNil();
            }
            return RubyString.newUnicodeString(runtime, vs);
        }
    }

    public static IRubyObject unmarshal_id_result(Ruby runtime, ResultSet rs) throws SQLException {
        try {
            if(rs.next()) {
                if(rs.getMetaData().getColumnCount() > 0) {
                    return runtime.newFixnum(rs.getLong(1));
                }
            }
            return runtime.getNil();
        } finally {
            try {
                rs.close();
            } catch(Exception e) {}
        }
    }

    private static String convertToStringOrNull(IRubyObject obj) {
        if (obj.isNil()) {
            return null;
        }
        return obj.toString();
    }
}
