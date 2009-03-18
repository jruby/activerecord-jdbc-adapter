/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2006-2009 Nick Sieger <nick@nicksieger.com>
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

import java.sql.Connection;

import org.jruby.RubyModule;
import org.jruby.RubyString;

import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.jruby.util.ByteList;

public class JdbcMySQLSpec {
    public static void load(RubyModule jdbcSpec) {
        RubyModule mysql = jdbcSpec.defineModuleUnder("MySQL");
        mysql.defineAnnotatedMethods(JdbcMySQLSpec.class);
    }

    private final static byte BACKQUOTE = '`';
    private final static byte[] QUOTED_DOT = new byte[] {'`', '.', '`'};

    private final static byte[] ZERO = new byte[] {'\\','0'};
    private final static byte[] NEWLINE = new byte[] {'\\','n'};
    private final static byte[] CARRIAGE = new byte[] {'\\','r'};
    private final static byte[] ZED = new byte[] {'\\','Z'};
    private final static byte[] DBL = new byte[] {'\\','"'};
    private final static byte[] SINGLE = new byte[] {'\\','\''};
    private final static byte[] ESCAPE = new byte[] {'\\','\\'};

    @JRubyMethod(name = "quote_string", required = 1, frame=false)
    public static IRubyObject quote_string(ThreadContext context, IRubyObject recv, IRubyObject string) {
        ByteList bytes = ((RubyString) string).getByteList();
        ByteList newBytes = new ByteList();
        
        newBytes.append(bytes);
        
        for(int i = newBytes.begin; i < newBytes.begin + newBytes.realSize; i++) {
            byte[] rep = null;
            switch (newBytes.bytes[i]) {
            case 0: rep = ZERO; break;
            case '\n': rep = NEWLINE; break;
            case '\r': rep = CARRIAGE; break;
            case 26: rep = ZED; break;
            case '"': rep = DBL; break;
            case '\'': rep = SINGLE; break;
            case '\\': rep = ESCAPE; break;
            }

            if (rep != null) {
                newBytes.replace(i, 1, rep);
                i += rep.length - 1; // We subtract one since for loop already adds one
            }
        }

        // Nothing changed, can return original
        if (newBytes.length() == bytes.length()) return string;

        return context.getRuntime().newString(newBytes);
    }

    @JRubyMethod(name = "quote_column_name", frame=false)
    public static IRubyObject quote_column_name(ThreadContext context, IRubyObject recv, IRubyObject arg) {
        ByteList bytes = arg.asString().getByteList();
        ByteList newBytes = new ByteList();

        newBytes.insert(0, BACKQUOTE);
        newBytes.append(bytes);
        newBytes.append(BACKQUOTE);

        return context.getRuntime().newString(newBytes);
    }
    
    @JRubyMethod(name = "quote_table_name", frame=false)
    public static IRubyObject quote_table_name(ThreadContext context, IRubyObject recv, IRubyObject arg) {
        ByteList bytes = arg.asString().getByteList();
        ByteList newBytes = new ByteList();

        newBytes.insert(0, BACKQUOTE);
        newBytes.append(bytes);
        int i = 0, j = 0;
        while ((i = newBytes.indexOf('.', j)) != -1) {
            newBytes.replace(i, 1, QUOTED_DOT);
            j = i+3;
        }
        newBytes.append(BACKQUOTE);

        return context.getRuntime().newString(newBytes);
    }

    /**
     * HACK HACK HACK See http://bugs.mysql.com/bug.php?id=36565
     * MySQL's statement cancel timer can cause memory leaks, so cancel it
     * if we loaded MySQL classes from the same classloader as JRuby
     */
    @JRubyMethod(module = true, frame = false)
    public static IRubyObject kill_cancel_timer(ThreadContext context, IRubyObject recv, IRubyObject raw_connection) {
        Connection conn = (Connection) raw_connection.dataGetStruct();
        if (conn != null && conn.getClass().getClassLoader() == recv.getRuntime().getJRubyClassLoader()) {
            try {
                java.lang.reflect.Field f = conn.getClass().getDeclaredField("cancelTimer");
                f.setAccessible(true);
                java.util.Timer timer = (java.util.Timer) f.get(null);
                timer.cancel();
            } catch (Exception e) {
            }
        }
        return recv.getRuntime().getNil();
    }
}
