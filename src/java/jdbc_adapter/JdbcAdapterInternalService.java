/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2006-2007 Nick Sieger <nick@nicksieger.com>
 * Copyright (c) 2006-2007 Ola Bini <ola.bini@gmail.com>
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

package jdbc_adapter;

import java.io.IOException;
import java.io.Reader;
import java.io.InputStream;
import java.io.ByteArrayInputStream;
import java.io.StringReader;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSetMetaData;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.sql.Types;

import java.text.DateFormat;
import java.text.SimpleDateFormat;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyModule;
import org.jruby.RubyNumeric;
import org.jruby.RubyString;
import org.jruby.RubySymbol;
import org.jruby.RubyTime;
import org.jruby.javasupport.Java;
import org.jruby.javasupport.JavaObject;
import org.jruby.runtime.Arity;
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
        cJdbcConn.defineMethod("with_connection_retry_guard",cf.getSingletonMethod("with_connection_retry_guard"));
        cJdbcConn.defineFastMethod("connection",cf.getFastSingletonMethod("connection"));
        cJdbcConn.defineFastMethod("reconnect!",cf.getFastSingletonMethod("reconnect"));
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
        cJdbcConn.defineFastMethod("columns",cf.getFastOptSingletonMethod("columns_internal"));
        cJdbcConn.defineFastMethod("columns_internal",cf.getFastOptSingletonMethod("columns_internal"));
        cJdbcConn.defineFastMethod("tables",cf.getFastOptSingletonMethod("tables"));

        cJdbcConn.defineFastMethod("insert_bind",cf.getFastOptSingletonMethod("insert_bind"));
        cJdbcConn.defineFastMethod("update_bind",cf.getFastOptSingletonMethod("update_bind"));

        cJdbcConn.defineFastMethod("write_large_object",cf.getFastOptSingletonMethod("write_large_object"));

        cJdbcConn.getMetaClass().defineFastMethod("insert?",cf.getFastSingletonMethod("insert_p", IRubyObject.class));
        cJdbcConn.getMetaClass().defineFastMethod("select?",cf.getFastSingletonMethod("select_p", IRubyObject.class));

        RubyModule jdbcSpec = runtime.getOrCreateModule("JdbcSpec");

        JdbcMySQLSpec.load(runtime, jdbcSpec);
        JdbcDerbySpec.load(runtime, jdbcSpec);
        return true;
    }

    private static int whitespace(int p, final int pend, ByteList bl) {
        while(p < pend) {
            switch(bl.bytes[p]) {
            case ' ':
            case '\n':
            case '\r':
            case '\t':
                p++;
                break;
            default:
                return p;
            }
        }
        return p;
    }

    public static IRubyObject insert_p(IRubyObject recv, IRubyObject _sql) {
        ByteList bl = _sql.convertToString().getByteList();

        int p = bl.begin;
        int pend = p + bl.realSize;

        p = whitespace(p, pend, bl);

        if(pend - p >= 6) {
            switch(bl.bytes[p++]) {
            case 'i':
            case 'I':
                switch(bl.bytes[p++]) {
                case 'n':
                case 'N':
                    switch(bl.bytes[p++]) {
                    case 's':
                    case 'S':
                        switch(bl.bytes[p++]) {
                        case 'e':
                        case 'E':
                            switch(bl.bytes[p++]) {
                            case 'r':
                            case 'R':
                                switch(bl.bytes[p++]) {
                                case 't':
                                case 'T':
                                    return recv.getRuntime().getTrue();
                                }
                            }
                        }
                    }
                }
            }
        }
        return recv.getRuntime().getFalse();
    }

    public static IRubyObject select_p(IRubyObject recv, IRubyObject _sql) {
        ByteList bl = _sql.convertToString().getByteList();

        int p = bl.begin;
        int pend = p + bl.realSize;

        p = whitespace(p, pend, bl);

        if(pend - p >= 6) {
            if(bl.bytes[p] == '(') {
                p++;
                p = whitespace(p, pend, bl);
            }
            if(pend - p >= 6) {
                switch(bl.bytes[p++]) {
                case 's':
                case 'S':
                    switch(bl.bytes[p++]) {
                    case 'e':
                    case 'E':
                        switch(bl.bytes[p++]) {
                        case 'l':
                        case 'L':
                            switch(bl.bytes[p++]) {
                            case 'e':
                            case 'E':
                                switch(bl.bytes[p++]) {
                                case 'c':
                                case 'C':
                                    switch(bl.bytes[p++]) {
                                    case 't':
                                    case 'T':
                                        return recv.getRuntime().getTrue();
                                    }
                                }
                            }
                        }
                    case 'h':
                    case 'H':
                        switch(bl.bytes[p++]) {
                        case 'o':
                        case 'O':
                            switch(bl.bytes[p++]) {
                            case 'w':
                            case 'W':
                                return recv.getRuntime().getTrue();
                            }
                        }
                    }
                }
            }
        }
        return recv.getRuntime().getFalse();
    }

    private static ResultSet intoResultSet(IRubyObject inp) {
        return (ResultSet)((inp instanceof JavaObject ? ((JavaObject)inp) : (((JavaObject)(inp.getInstanceVariable("@java_object"))))).getValue());
    }   

    private static boolean isConnectionBroken(Connection c) {
        // TODO: better way of determining if the connection is active
        try {
            return c.isClosed();
        } catch (SQLException sx) {
            return true;
        }
    }

    private static IRubyObject setConnection(IRubyObject recv, Connection c) {
        Connection prev = getConnection(recv);
        if (prev != null) {
            try {
                prev.close();
            } catch(Exception e) {}
        }
        recv.setInstanceVariable("@connection", wrappedConnection(recv,c));
        recv.dataWrapStruct(c);
        return recv;
    }

    public static IRubyObject connection(IRubyObject recv) {
        Connection c = getConnection(recv);
        if (c == null) {
            reconnect(recv);
        }
        return recv.getInstanceVariable("@connection");
    }

    public static IRubyObject reconnect(IRubyObject recv) {
        IRubyObject connection_factory = recv.getInstanceVariable("@connection_factory");
        JdbcConnectionFactory factory = (JdbcConnectionFactory)
                ((JavaObject) connection_factory.getInstanceVariable("@java_object")).getValue();        
        setConnection(recv, factory.newConnection());
        return recv;
    }

    public static IRubyObject with_connection_retry_guard(final IRubyObject recv, final Block block) {
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                return block.call(recv.getRuntime().getCurrentContext(), new IRubyObject[] {
                    wrappedConnection(recv, c)
                });
            }
        });
    }

    private static IRubyObject withConnectionAndRetry(IRubyObject recv, SQLBlock block) {
        final int TRIES = 10;
        int i = 0;
        Throwable toWrap = null;
        while (i < TRIES) {
            Connection c = getConnection(recv);
            try {
                return block.call(c);
            } catch (SQLException e) {
                i++;
                toWrap = e;
                if (isConnectionBroken(c)) {
                    reconnect(recv);
                } else {
                    throw wrap(recv, e);
                }
            }
        }
        throw wrap(recv, toWrap);
    }

    public static IRubyObject tables(final IRubyObject recv, IRubyObject[] args) {
        final Ruby runtime     = recv.getRuntime();
        final String catalog   = getCatalog(args);
        final String schemapat = getSchemaPattern(args);
        final String tablepat  = getTablePattern(args);
        final String[] types   = getTypes(args);

        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                ResultSet rs = null;
                try {
                    DatabaseMetaData metadata = c.getMetaData();
                    String clzName = metadata.getClass().getName().toLowerCase();
                    boolean isOracle = clzName.indexOf("oracle") != -1 || clzName.indexOf("oci") != -1;

                    String realschema = schemapat;
                    if (realschema == null && isOracle) {
                        ResultSet schemas = metadata.getSchemas();
                        String username = metadata.getUserName();
                        while (schemas.next()) {
                            if (schemas.getString(1).equalsIgnoreCase(username)) {
                                realschema = schemas.getString(1);
                                break;
                            }
                        }
                        schemas.close();
                    }
                    rs = metadata.getTables(catalog, realschema, tablepat, types);
                    List arr = new ArrayList();
                    while (rs.next()) {
                        String name = rs.getString(3).toLowerCase();
                        // Handle stupid Oracle 10g RecycleBin feature
                        if (!isOracle || !name.startsWith("bin$")) {
                            arr.add(runtime.newString(name));
                        }
                    }
                    return runtime.newArray(arr);
                } finally {
                    try { rs.close(); } catch (Exception e) { }
                }
            }
        });
    }

    private static String getCatalog(IRubyObject[] args) {
        if (args != null && args.length > 0) {
            return convertToStringOrNull(args[0]);
        }
        return null;
    }

    private static String getSchemaPattern(IRubyObject[] args) {
        if (args != null && args.length > 1) {
            return convertToStringOrNull(args[1]);
        }
        return null;
    }

    private static String getTablePattern(IRubyObject[] args) {
        if (args != null && args.length > 2) {
            return convertToStringOrNull(args[2]);
        }
        return null;
    }

    private static String[] getTypes(IRubyObject[] args) {
        String[] types = new String[]{"TABLE"};
        if (args != null && args.length > 3) {
            IRubyObject typearr = args[3];
            if (typearr instanceof RubyArray) {
                IRubyObject[] arr = ((RubyArray) typearr).toJavaArray();
                types = new String[arr.length];
                for (int i = 0; i < types.length; i++) {
                    types[i] = arr[i].toString();
                }
            } else {
                types = new String[]{types.toString()};
            }
        }
        return types;
    }

    public static IRubyObject native_database_types(IRubyObject recv) {
        return recv.getInstanceVariable("@tps");
    }    

    public static IRubyObject set_native_database_types(IRubyObject recv) throws SQLException, IOException {
        Ruby runtime = recv.getRuntime();
        ThreadContext ctx = runtime.getCurrentContext();
        IRubyObject types = unmarshal_result_downcase(recv, getConnection(recv).getMetaData().getTypeInfo());
        recv.setInstanceVariable("@native_types", 
                                 ((RubyModule)(runtime.getModule("ActiveRecord").getConstant("ConnectionAdapters"))).
                                 getConstant("JdbcTypeConverter").callMethod(ctx,"new", types).
                                 callMethod(ctx, "choose_best_types"));
        return runtime.getNil();
    }

    public static IRubyObject database_name(IRubyObject recv) throws SQLException {
        String name = getConnection(recv).getCatalog();
        if(null == name) {
            name = getConnection(recv).getMetaData().getUserName();
            if(null == name) {
                name = "db1";
            }
        }
        return recv.getRuntime().newString(name);
    }

    public static IRubyObject begin(IRubyObject recv) throws SQLException {
        getConnection(recv).setAutoCommit(false);
        return recv.getRuntime().getNil();
    }

    public static IRubyObject commit(IRubyObject recv) throws SQLException {
        try {
            getConnection(recv).commit();
            return recv.getRuntime().getNil();
        } finally {
            getConnection(recv).setAutoCommit(true);
        }
    }

    public static IRubyObject rollback(IRubyObject recv) throws SQLException {
        try {
            getConnection(recv).rollback();
            return recv.getRuntime().getNil();
        } finally {
            getConnection(recv).setAutoCommit(true);
        }
    }

    public static IRubyObject columns_internal(final IRubyObject recv, final IRubyObject[] args) throws SQLException, IOException {
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                ResultSet results = null;
                try {
                    String table_name = args[0].convertToString().getUnicodeValue();
                    DatabaseMetaData metadata = c.getMetaData();
                    String clzName = metadata.getClass().getName().toLowerCase();
                    boolean isDerby = clzName.indexOf("derby") != -1;
                    boolean isOracle = clzName.indexOf("oracle") != -1 || clzName.indexOf("oci") != -1;
                    String schemaName = null;
                    if(args.length>2) {
                        schemaName = args[2].toString();
                    }
                    if(metadata.storesUpperCaseIdentifiers()) {
                        table_name = table_name.toUpperCase();
                    } else if(metadata.storesLowerCaseIdentifiers()) {
                        table_name = table_name.toLowerCase();
                    }
                    if(schemaName == null && (isDerby || isOracle)) {
                        ResultSet schemas = metadata.getSchemas();
                        String username = metadata.getUserName();
                        while(schemas.next()) {
                            if(schemas.getString(1).equalsIgnoreCase(username)) {
                                schemaName = schemas.getString(1);
                                break;
                            }
                        }
                        schemas.close();
                    }

                    results = metadata.getColumns(c.getCatalog(),schemaName,table_name,null);
                    return unmarshal_columns(recv, metadata, results);
                } finally {
                    try { if (results != null) results.close(); } catch (SQLException sqx) {}
                }
            }
        });
    }

    private static final java.util.regex.Pattern HAS_SMALL = java.util.regex.Pattern.compile("[a-z]");
    private static IRubyObject unmarshal_columns(IRubyObject recv, DatabaseMetaData metadata, ResultSet rs) throws SQLException {
        try {
            List columns = new ArrayList();
            String clzName = metadata.getClass().getName().toLowerCase();
            boolean isDerby = clzName.indexOf("derby") != -1;
            boolean isOracle = clzName.indexOf("oracle") != -1 || clzName.indexOf("oci") != -1;
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
                if(def == null || (isOracle && def.toLowerCase().trim().equals("null"))) {
                    _def = runtime.getNil();
                } else {
                    if(isOracle) {
                        def = def.trim();
                    }
                    if((isDerby || isOracle) && def.length() > 0 && def.charAt(0) == '\'') {
                        def = def.substring(1, def.length()-1);
                    }
                    _def = runtime.newString(def);
                }
                IRubyObject c = jdbcCol.callMethod(ctx,"new", new IRubyObject[]{recv.getInstanceVariable("@config"), runtime.newString(column_name),
                                                                                _def, runtime.newString(type), 
                                                                                runtime.newBoolean(!rs.getString(18).trim().equals("NO"))});
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

    public static IRubyObject primary_keys(final IRubyObject recv, final IRubyObject _table_name) throws SQLException {
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                DatabaseMetaData metadata = c.getMetaData();
                String table_name = _table_name.toString();
                if (metadata.storesUpperCaseIdentifiers()) {
                    table_name = table_name.toUpperCase();
                } else if (metadata.storesLowerCaseIdentifiers()) {
                    table_name = table_name.toLowerCase();
                }
                ResultSet result_set = metadata.getPrimaryKeys(null, null, table_name);
                List keyNames = new ArrayList();
                Ruby runtime = recv.getRuntime();
                while (result_set.next()) {
                    String s1 = result_set.getString(4);
                    if (metadata.storesUpperCaseIdentifiers() && !HAS_SMALL.matcher(s1).find()) {
                        s1 = s1.toLowerCase();
                    }
                    keyNames.add(runtime.newString(s1));
                }

                try {
                    result_set.close();
                } catch (Exception e) {
                }

                return runtime.newArray(keyNames);
            }
        });
    }

    public static IRubyObject execute_id_insert(IRubyObject recv, final IRubyObject sql, final IRubyObject id) throws SQLException {
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                PreparedStatement ps = c.prepareStatement(sql.convertToString().getUnicodeValue());
                try {
                    ps.setLong(1, RubyNumeric.fix2long(id));
                    ps.executeUpdate();
                } finally {
                    ps.close();
                }
                return id;
            }
        });
    }

    public static IRubyObject execute_update(final IRubyObject recv, final IRubyObject sql) throws SQLException {
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                Statement stmt = null;
                try {
                    stmt = c.createStatement();
                    return recv.getRuntime().newFixnum(stmt.executeUpdate(sql.convertToString().getUnicodeValue()));
                } finally {
                    if (null != stmt) {
                        try {
                            stmt.close();
                        } catch (Exception e) {
                        }
                    }
                }
            }
        });
    }

    public static IRubyObject execute_query(final IRubyObject recv, IRubyObject[] args) throws SQLException, IOException {
        final IRubyObject sql = args[0];
        final int maxrows;

        if (args.length > 1) {
            maxrows = RubyNumeric.fix2int(args[1]);
        } else {
            maxrows = 0;
        }
        
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                Statement stmt = null;
                try {
                    stmt = c.createStatement();
                    stmt.setMaxRows(maxrows);
                    return unmarshal_result(recv, stmt.executeQuery(sql.convertToString().getUnicodeValue()));
                } finally {
                    if (null != stmt) {
                        try {
                            stmt.close();
                        } catch (Exception e) {
                        }
                    }
                }
            }
        });
    }

    public static IRubyObject execute_insert(final IRubyObject recv, final IRubyObject sql) throws SQLException {
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                Statement stmt = null;
                try {
                    stmt = c.createStatement();
                    stmt.executeUpdate(sql.convertToString().getUnicodeValue(), Statement.RETURN_GENERATED_KEYS);
                    return unmarshal_id_result(recv.getRuntime(), stmt.getGeneratedKeys());
                } finally {
                    if (null != stmt) {
                        try {
                            stmt.close();
                        } catch (Exception e) {
                        }
                    }
                }
            }
        });
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

    public static IRubyObject unmarshal_result(IRubyObject recv, ResultSet rs) throws SQLException {
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

    private static IRubyObject jdbc_to_ruby(Ruby runtime, int row, int type, int scale, ResultSet rs) throws SQLException {
        try {
            int n;
            switch (type) {
                case Types.BINARY:
                case Types.BLOB:
                case Types.LONGVARBINARY:
                case Types.VARBINARY:
                    InputStream is = rs.getBinaryStream(row);
                    if (is == null || rs.wasNull()) {
                        return runtime.getNil();
                    }
                    ByteList str = new ByteList(2048);
                    byte[] buf = new byte[2048];

                    while ((n = is.read(buf)) != -1) {
                        str.append(buf, 0, n);
                    }
                    is.close();

                    return runtime.newString(str);
                case Types.LONGVARCHAR:
                case Types.CLOB:
                    Reader rss = rs.getCharacterStream(row);
                    if (rss == null || rs.wasNull()) {
                        return runtime.getNil();
                    }
                    StringBuffer str2 = new StringBuffer(2048);
                    char[] cuf = new char[2048];
                    while ((n = rss.read(cuf)) != -1) {
                        str2.append(cuf, 0, n);
                    }
                    rss.close();
                    return RubyString.newUnicodeString(runtime, str2.toString());
                case Types.TIMESTAMP:
                    Timestamp time = rs.getTimestamp(row);
                    if (time == null || rs.wasNull()) {
                        return runtime.getNil();
                    }
                    String sttr = time.toString();
                    if (sttr.endsWith(" 00:00:00.0")) {
                        sttr = sttr.substring(0, sttr.length() - (" 00:00:00.0".length()));
                    }
                    return RubyString.newUnicodeString(runtime, sttr);
                default:
                    String vs = rs.getString(row);
                    if (vs == null || rs.wasNull()) {
                        return runtime.getNil();
                    }

                    return RubyString.newUnicodeString(runtime, vs);
            }
        } catch (IOException ioe) {
            throw (SQLException) new SQLException(ioe.getMessage()).initCause(ioe);
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

    private static int getTypeValueFor(Ruby runtime, IRubyObject type) throws SQLException {
        if(!(type instanceof RubySymbol)) {
            type = type.callMethod(runtime.getCurrentContext(),"type");
        }
        if(type == runtime.newSymbol("string")) {
            return Types.VARCHAR;
        } else if(type == runtime.newSymbol("text")) {
            return Types.CLOB;
        } else if(type == runtime.newSymbol("integer")) {
            return Types.INTEGER;
        } else if(type == runtime.newSymbol("decimal")) {
            return Types.DECIMAL;
        } else if(type == runtime.newSymbol("float")) {
            return Types.FLOAT;
        } else if(type == runtime.newSymbol("datetime")) {
            return Types.TIMESTAMP;
        } else if(type == runtime.newSymbol("timestamp")) {
            return Types.TIMESTAMP;
        } else if(type == runtime.newSymbol("time")) {
            return Types.TIME;
        } else if(type == runtime.newSymbol("date")) {
            return Types.DATE;
        } else if(type == runtime.newSymbol("binary")) {
            return Types.BLOB;
        } else if(type == runtime.newSymbol("boolean")) {
            return Types.BOOLEAN;
        } else {
            return -1;
        }
    }
    
    private final static DateFormat FORMAT = new SimpleDateFormat("%y-%M-%d %H:%m:%s");

    private static void setValue(PreparedStatement ps, int index, Ruby runtime, IRubyObject value, IRubyObject type) throws SQLException {
        final int tp = getTypeValueFor(runtime, type);
        if(value.isNil()) {
            ps.setNull(index, tp);
            return;
        }

        switch(tp) {
        case Types.VARCHAR:
        case Types.CLOB:
            ps.setString(index, RubyString.objAsString(value).toString());
            break;
        case Types.INTEGER:
            ps.setLong(index, RubyNumeric.fix2long(value));
            break;
        case Types.FLOAT:
            ps.setDouble(index, ((RubyNumeric)value).getDoubleValue());
            break;
        case Types.TIMESTAMP:
        case Types.TIME:
        case Types.DATE:
            if(!(value instanceof RubyTime)) {
                try {
                    Date dd = FORMAT.parse(RubyString.objAsString(value).toString());
                    ps.setTimestamp(index, new java.sql.Timestamp(dd.getTime()), Calendar.getInstance());
                } catch(Exception e) {
                    ps.setString(index, RubyString.objAsString(value).toString());
                }
            } else {
                RubyTime rubyTime = (RubyTime) value;
                java.util.Date date = rubyTime.getJavaDate();
                long millis = date.getTime();
                long micros = rubyTime.microseconds() - millis / 1000;
                java.sql.Timestamp ts = new java.sql.Timestamp(millis);
                java.util.Calendar cal = Calendar.getInstance();
                cal.setTime(date);
                ts.setNanos((int)(micros * 1000));
                ps.setTimestamp(index, ts, cal);
            }
            break;
        case Types.BOOLEAN:
            ps.setBoolean(index, value.isTrue());
            break;
        default: throw new RuntimeException("type " + type + " not supported in _bind yet");
        }
    }

    private static void setValuesOnPS(PreparedStatement ps, Ruby runtime, IRubyObject values, IRubyObject types) throws SQLException {
        RubyArray vals = (RubyArray)values;
        RubyArray tps = (RubyArray)types;

        for(int i=0, j=vals.getLength(); i<j; i++) {
            setValue(ps, i+1, runtime, vals.eltInternal(i), tps.eltInternal(i));
        }
    }

    /*
     * sql, values, types, name = nil, pk = nil, id_value = nil, sequence_name = nil
     */
    public static IRubyObject insert_bind(IRubyObject recv, final IRubyObject[] args) throws SQLException {
        final Ruby runtime = recv.getRuntime();
        Arity.checkArgumentCount(runtime, args, 3, 7);
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                PreparedStatement ps = null;
                try {
                    ps = c.prepareStatement(RubyString.objAsString(args[0]).toString(), Statement.RETURN_GENERATED_KEYS);
                    setValuesOnPS(ps, runtime, args[1], args[2]);
                    ps.executeUpdate();
                    return unmarshal_id_result(runtime, ps.getGeneratedKeys());
                } finally {
                    try {
                        ps.close();
                    } catch (Exception e) {
                    }
                }
            }
        });
    }

    /*
     * sql, values, types, name = nil
     */
    public static IRubyObject update_bind(IRubyObject recv, final IRubyObject[] args) throws SQLException {
        final Ruby runtime = recv.getRuntime();
        Arity.checkArgumentCount(runtime, args, 3, 4);
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                PreparedStatement ps = null;
                try {
                    ps = c.prepareStatement(RubyString.objAsString(args[0]).toString());
                    setValuesOnPS(ps, runtime, args[1], args[2]);
                    ps.executeUpdate();
                } finally {
                    try {
                        ps.close();
                    } catch (Exception e) {
                    }
                }
                return runtime.getNil();
            }
        });
    }

    /*
     * (is binary?, colname, tablename, primary key, id, value)
     */
    public static IRubyObject write_large_object(IRubyObject recv, final IRubyObject[] args)
            throws SQLException, IOException {
        final Ruby runtime = recv.getRuntime();
        Arity.checkArgumentCount(runtime, args, 6, 6);
        return withConnectionAndRetry(recv, new SQLBlock() {
            public IRubyObject call(Connection c) throws SQLException {
                String sql = "UPDATE " + args[2].toString() + " SET " + args[1].toString() 
                        + " = ? WHERE " + args[3] + "=" + args[4];
                PreparedStatement ps = null;
                try {
                    ByteList outp = RubyString.objAsString(args[5]).getByteList();
                    ps = c.prepareStatement(sql);
                    if (args[0].isTrue()) { // binary
                        ps.setBinaryStream(1, new ByteArrayInputStream(outp.bytes, 
                                outp.begin, outp.realSize), outp.realSize);
                    } else { // clob
                        String ss = outp.toString();
                        ps.setCharacterStream(1, new StringReader(ss), ss.length());
                    }
                    ps.executeUpdate();
                } finally {
                    try {
                        ps.close();
                    } catch (Exception e) {
                    }
                }
                return runtime.getNil();
            }
        });
    }

    private static Connection getConnection(IRubyObject recv) {
        Connection conn = (Connection) recv.dataGetStruct();
        return conn;
    }

    private static RuntimeException wrap(IRubyObject recv, Throwable exception) {
        return recv.getRuntime().newArgumentError(exception.getMessage());
    }

    private static IRubyObject wrappedConnection(IRubyObject recv, Connection c) {
        return Java.java_to_ruby(recv, JavaObject.wrap(recv.getRuntime(), c), Block.NULL_BLOCK);
    }
}
