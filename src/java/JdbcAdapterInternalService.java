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

import java.sql.ResultSetMetaData;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.Map;

import org.jruby.Ruby;
import org.jruby.RubyBigDecimal;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyModule;
import org.jruby.RubyNumeric;
import org.jruby.javasupport.JavaObject;
import org.jruby.runtime.Block;
import org.jruby.runtime.CallbackFactory;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.BasicLibraryService;

public class JdbcAdapterInternalService implements BasicLibraryService {
    public boolean basicLoad(final Ruby runtime) throws IOException {
        RubyClass cJdbcConn = ((RubyModule)(runtime.getModule("ActiveRecord").getConstant("ConnectionAdapters"))).
            defineClassUnder("JdbcConnection",runtime.getObject(),runtime.getObject().getAllocator());

        CallbackFactory cf = runtime.callbackFactory(JdbcAdapterInternalService.class);
        cJdbcConn.defineMethod("unmarshal_result",cf.getSingletonMethod("unmarshal_result", IRubyObject.class));
        cJdbcConn.defineFastMethod("unmarshal_id_result",cf.getFastSingletonMethod("unmarshal_id_result", IRubyObject.class));
        return true;
    }

    private static ResultSet intoResultSet(IRubyObject inp) {
        return (ResultSet)(((JavaObject)(inp.callMethod(inp.getRuntime().getCurrentContext(),"java_object"))).getValue());
    }

    public static IRubyObject unmarshal_result(IRubyObject recv, IRubyObject resultset, Block row_filter) throws SQLException {
        Ruby runtime = recv.getRuntime();
        ResultSet rs = intoResultSet(resultset);
        ResultSetMetaData metadata = rs.getMetaData();
        int col_count = metadata.getColumnCount();
        String[] col_names = new String[col_count];
        int[] col_types = new int[col_count];
        int[] col_scale = new int[col_count];

        for(int i=0;i<col_count;i++) {
            col_names[i] = metadata.getColumnName(i+1);
            col_types[i] = metadata.getColumnType(i+1);
            col_scale[i] = metadata.getScale(i+1);
        }

        List results = new ArrayList();

        if(row_filter.isGiven()) {
            while(rs.next()) {
                if(row_filter.yield(runtime.getCurrentContext(),resultset).isTrue()) {
                    Map row = RubyHash.newHash(runtime);
                    for(int i=0;i<col_count;i++) {
                        row.put(runtime.newString(col_names[i].toLowerCase()), jdbc_to_ruby(runtime, i+1, col_types[i], col_scale[i], rs));
                    }
                    results.add(row);
                }
            }
        } else {
            while(rs.next()) {
                Map row = RubyHash.newHash(runtime);
                for(int i=0;i<col_count;i++) {
                    row.put(runtime.newString(col_names[i].toLowerCase()), jdbc_to_ruby(runtime, i+1, col_types[i], col_scale[i], rs));
                }
                results.add(row);
            }
        }
 
        return runtime.newArray(results);
    }

    private static IRubyObject to_ruby_time(Ruby runtime, Date t) {
        if(t != null) {
            long ti = t.getTime();
            return runtime.getClass("Time").callMethod(runtime.getCurrentContext(),"at",new IRubyObject[]{
                    runtime.newFixnum(ti/1000), runtime.newFixnum((ti%1000)*1000)});
        } else {
            return runtime.getNil();
        }
    }

    private static IRubyObject to_ruby_date(Ruby runtime, Date d) {
        if(d != null) {
            Calendar cal = Calendar.getInstance();
            cal.setTime(d);
            return runtime.getClass("Date").callMethod(runtime.getCurrentContext(),"new",new IRubyObject[]{
                    runtime.newFixnum(cal.get(Calendar.YEAR)),
                    runtime.newFixnum(cal.get(Calendar.MONTH)+1),
                    runtime.newFixnum(cal.get(Calendar.DATE))
                });
        } else {
            return runtime.getNil();
        }
    }

    private static IRubyObject jdbc_to_ruby(Ruby runtime, int row, int type, int scale, ResultSet rs) throws SQLException {
        String vs = rs.getString(row);
        if(vs == null) {
            return runtime.getNil();
        }
        return runtime.newString(vs);
    }

    public static IRubyObject unmarshal_id_result(IRubyObject recv, IRubyObject resultset) throws SQLException {
        Ruby runtime = recv.getRuntime();
        ResultSet rs = intoResultSet(resultset);
        ResultSetMetaData metadata = rs.getMetaData();
        int col_count = metadata.getColumnCount();
        int[] col_types = new int[col_count];
        int[] col_scale = new int[col_count];

        for(int i=0;i<col_count;i++) {
            col_types[i] = metadata.getColumnType(i+1);
            col_scale[i] = metadata.getScale(i+1);
        }

        List results = new ArrayList();

        while(rs.next()) {
            Map row = RubyHash.newHash(runtime);
            for(int i=0;i<col_count;i++) {
                row.put(runtime.newString(""+(i+1)), jdbc_to_ruby(runtime, i+1, col_types[i], col_scale[i], rs));
            }
            results.add(row);
        }

        return runtime.newArray(results);
    }
}
