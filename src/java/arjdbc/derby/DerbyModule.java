/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2006-2011 Nick Sieger <nick@nicksieger.com>
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

package arjdbc.derby;

import java.sql.SQLException;

import static arjdbc.util.QuotingUtils.BYTES_0;
import static arjdbc.util.QuotingUtils.BYTES_1;

import arjdbc.jdbc.RubyJdbcConnection;

import org.jruby.Ruby;
import org.jruby.RubyBoolean;
import org.jruby.RubyModule;
import org.jruby.RubyObjectAdapter;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

public class DerbyModule {
    
    private static RubyObjectAdapter rubyApi;
    
    public static void load(final RubyModule arJdbc) {
        RubyModule derby = arJdbc.defineModuleUnder("Derby");
        derby.defineAnnotatedMethods(DerbyModule.class);
        RubyModule column = derby.defineModuleUnder("Column");
        column.defineAnnotatedMethods(Column.class);
        rubyApi = JavaEmbedUtils.newObjectAdapter();
    }

    public static class Column {
        @JRubyMethod(name = "type_cast", required = 1)
        public static IRubyObject type_cast(IRubyObject recv, IRubyObject value) {
            Ruby runtime = recv.getRuntime();

            if (value.isNil() || ((value instanceof RubyString) && value.toString().trim().equalsIgnoreCase("null"))) {
                return runtime.getNil();
            }

            String type = rubyApi.getInstanceVariable(recv, "@type").toString();

            switch (type.charAt(0)) {
            case 's': //string
                return value;
            case 't': //text, timestamp, time
                if (type.equals("text")) {
                    return value;
                } else if (type.equals("timestamp")) {
                    return rubyApi.callMethod(recv.getMetaClass(), "string_to_time", value);
                } else { //time
                    return rubyApi.callMethod(recv.getMetaClass(), "string_to_dummy_time", value);
                }
            case 'i': //integer
            case 'p': //primary key
                if (value.respondsTo("to_i")) {
                    return rubyApi.callMethod(value, "to_i");
                } else {
                    return runtime.newFixnum(value.isTrue() ? 1 : 0);
                }
            case 'd': //decimal, datetime, date
                if (type.equals("datetime")) {
                    return rubyApi.callMethod(recv.getMetaClass(), "string_to_time", value);
                } else if (type.equals("date")) {
                    return rubyApi.callMethod(recv.getMetaClass(), "string_to_date", value);
                } else {
                    return rubyApi.callMethod(recv.getMetaClass(), "value_to_decimal", value);
                }
            case 'f': //float
                return rubyApi.callMethod(value, "to_f");
            case 'b': //binary, boolean
                if (type.equals("binary")) {
                    return rubyApi.callMethod(recv.getMetaClass(), "binary_to_string", value);
                } else {
                    return rubyApi.callMethod(recv.getMetaClass(), "value_to_boolean", value);
                }
            }
            return value;
        }
    }

    @JRubyMethod(name = "quote", required = 1, optional = 1)
    public static IRubyObject quote(ThreadContext context, IRubyObject recv, IRubyObject[] args) {
        Ruby runtime = recv.getRuntime();
        IRubyObject value = args[0];
        if (args.length > 1) {
            IRubyObject col = args[1];
            String type = col.isNil() ? "" : rubyApi.callMethod(col, "type").toString();
            // intercept and change value, maybe, if the column type is :text or :string
            if (type.equals("text") || type.equals("string")) {
            	value = make_ruby_string_for_text_column(context, recv, runtime, value);
            }
            String metaClass = value.getMetaClass().getName();

            if (value instanceof RubyString) {
                if (type.equals("string")) {
                    return quote_string_with_surround(runtime, "'", (RubyString)value, "'");
                } else if (type.equals("text")) {
                    return quote_string_with_surround(runtime, "CAST('", (RubyString)value, "' AS CLOB)");
                } else if (type.equals("binary")) {
                    return hexquote_string_with_surround(runtime, "CAST(X'", (RubyString)value, "' AS BLOB)");
                } else {
                    // column type :integer or other numeric or date version
                    if (only_digits((RubyString)value)) {
                        return value;
                    } else {
                        return super_quote(context, recv, runtime, value, col);
                    }
                }
            } else if (metaClass.equals("Float") || metaClass.equals("Fixnum") || metaClass.equals("Bignum")) {
                if (type.equals("string")) {
                    return quote_string_with_surround(runtime, "'", RubyString.objAsString(context, value), "'");
                }
            }
        }
        return super_quote(context, recv, runtime, value, runtime.getNil());
    }

    /*
     * Derby is not permissive like MySql. Try and send an Integer to a CLOB or VARCHAR column and Derby will vomit.
     * This method turns non stringy things into strings.
     */
    private static IRubyObject make_ruby_string_for_text_column(ThreadContext context, IRubyObject recv, Ruby runtime, IRubyObject value) {
    	RubyModule multibyteChars = (RubyModule)
            ((RubyModule) ((RubyModule) runtime.getModule("ActiveSupport")).getConstant("Multibyte")).getConstantAt("Chars");
        if (value instanceof RubyString || rubyApi.isKindOf(value, multibyteChars) || value.isNil()) {
            return value;
        }

        String metaClass = value.getMetaClass().getName();

        if (value instanceof RubyBoolean) {
            return value.isTrue() ? runtime.newString("1") : runtime.newString("0");
        } else if (metaClass.equals("Float") || metaClass.equals("Fixnum") || metaClass.equals("Bignum")) {
            return RubyString.objAsString(context, value);
        } else if (metaClass.equals("BigDecimal")) {
            return rubyApi.callMethod(value, "to_s", runtime.newString("F"));
        } else {
            if (rubyApi.callMethod(value, "acts_like?", runtime.newString("date")).isTrue() || rubyApi.callMethod(value, "acts_like?", runtime.newString("time")).isTrue()) {
                return (RubyString)rubyApi.callMethod(recv, "quoted_date", value);
            } else {
                return (RubyString)rubyApi.callMethod(value, "to_yaml");
            }
        }
    }

    private final static ByteList NULL = new ByteList("NULL".getBytes());

    private static IRubyObject super_quote(ThreadContext context, IRubyObject recv, Ruby runtime, IRubyObject value, IRubyObject col) {
        if (value.respondsTo("quoted_id")) {
            return rubyApi.callMethod(value, "quoted_id");
        }

        String metaClass = value.getMetaClass().getName();

        IRubyObject type = (col.isNil()) ? col : rubyApi.callMethod(col, "type");
        RubyModule multibyteChars = (RubyModule)
            ((RubyModule) ((RubyModule) runtime.getModule("ActiveSupport")).getConstant("Multibyte")).getConstantAt("Chars");
        if (value instanceof RubyString || rubyApi.isKindOf(value, multibyteChars)) {
            RubyString svalue = RubyString.objAsString(context, value);
            if (type == runtime.newSymbol("binary") && col.getType().respondsTo("string_to_binary")) {
                return quote_string_with_surround(runtime, "'", (RubyString)(rubyApi.callMethod(col.getType(), "string_to_binary", svalue)), "'");
            } else if (type == runtime.newSymbol("integer") || type == runtime.newSymbol("float")) {
                return RubyString.objAsString(context, ((type == runtime.newSymbol("integer")) ?
                                                        rubyApi.callMethod(svalue, "to_i") :
                                                        rubyApi.callMethod(svalue, "to_f")));
            } else {
                return quote_string_with_surround(runtime, "'", svalue, "'");
            }
        } else if (value.isNil()) {
            return runtime.newString(NULL);
        } else if (value instanceof RubyBoolean) {
            return (value.isTrue() ?
                    (type == runtime.newSymbol(":integer")) ? runtime.newString("1") : rubyApi.callMethod(recv, "quoted_true") :
                    (type == runtime.newSymbol(":integer")) ? runtime.newString("0") : rubyApi.callMethod(recv, "quoted_false"));
        } else if (metaClass.equals("Float") || metaClass.equals("Fixnum") || metaClass.equals("Bignum")) {
            return RubyString.objAsString(context, value);
        } else if (metaClass.equals("BigDecimal")) {
            return rubyApi.callMethod(value, "to_s", runtime.newString("F"));
        } else if (rubyApi.callMethod(value, "acts_like?", runtime.newString("date")).isTrue() || rubyApi.callMethod(value, "acts_like?", runtime.newString("time")).isTrue()) {
            return quote_string_with_surround(runtime, "'", (RubyString)(rubyApi.callMethod(recv, "quoted_date", value)), "'");
        } else {
            return quote_string_with_surround(runtime, "'", (RubyString)(rubyApi.callMethod(value, "to_yaml")), "'");
        }
    }

    private final static ByteList TWO_SINGLE = new ByteList(new byte[]{'\'','\''});

    private static IRubyObject quote_string_with_surround(Ruby runtime, String before, RubyString string, String after) {
        ByteList input = string.getByteList();
        ByteList output = new ByteList(before.getBytes(), input.encoding);
        for(int i = input.begin; i< input.begin + input.realSize; i++) {
            switch(input.bytes[i]) {
            case '\'':
                output.append(input.bytes[i]);
                //FALLTHROUGH
            default:
                output.append(input.bytes[i]);
            }

        }

        output.append(after.getBytes());

        return runtime.newString(output);
    }

    private final static byte[] HEX = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};

    private static IRubyObject hexquote_string_with_surround(Ruby runtime, String before, RubyString string, String after) {
        ByteList input = string.getByteList();
        ByteList output = new ByteList(before.getBytes());
        int written = 0;
        for(int i = input.begin; i< input.begin + input.realSize; i++) {
            byte b1 = input.bytes[i];
            byte higher = HEX[(((char)b1)>>4)%16];
            byte lower = HEX[((char)b1)%16];
            output.append(higher);
            output.append(lower);
            written += 2;
            if(written >= 16334) { // max hex length = 16334
                output.append("'||X'".getBytes());
                written = 0;
            }
        }

        output.append(after.getBytes());
        return runtime.newStringShared(output);
    }

    private static boolean only_digits(RubyString inp) {
        ByteList input = inp.getByteList();
        for(int i = input.begin; i< input.begin + input.realSize; i++) {
            if(input.bytes[i] < '0' || input.bytes[i] > '9') {
                return false;
            }
        }
        return true;
    }

    @JRubyMethod(name = "quote_string", required = 1)
    public static IRubyObject quote_string(IRubyObject recv, IRubyObject string) {
        boolean replacementFound = false;
        ByteList bl = ((RubyString) string).getByteList();

        for(int i = bl.begin; i < bl.begin + bl.realSize; i++) {
            switch (bl.bytes[i]) {
            case '\'': break;
            default: continue;
            }

            // On first replacement allocate a different bytelist so we don't manip original
            if(!replacementFound) {
                i-= bl.begin;
                bl = new ByteList(bl);
                replacementFound = true;
            }

            bl.replace(i, 1, TWO_SINGLE);
            i+=1;
        }
        if(replacementFound) {
            return recv.getRuntime().newStringShared(bl);
        } else {
            return string;
        }
    }

    @JRubyMethod(name = "quoted_true", required = 0, frame = false)
    public static IRubyObject quoted_true(
            final ThreadContext context, 
            final IRubyObject self) {
        return RubyString.newString(context.getRuntime(), BYTES_1);
    }
    
    @JRubyMethod(name = "quoted_false", required = 0, frame = false)
    public static IRubyObject quoted_false(
            final ThreadContext context, 
            final IRubyObject self) {
        return RubyString.newString(context.getRuntime(), BYTES_0);
    }
    
    @JRubyMethod(name = "select_all", rest = true)
    public static IRubyObject select_all(IRubyObject recv, IRubyObject[] args) {
        return rubyApi.callMethod(recv, "execute", args);
    }

    @JRubyMethod(name = "select_one", rest = true)
    public static IRubyObject select_one(IRubyObject recv, IRubyObject[] args) {
        IRubyObject limit = rubyApi.getInstanceVariable(recv, "@limit");
        if (limit == null || limit.isNil()) {
            rubyApi.setInstanceVariable(recv, "@limit", recv.getRuntime().newFixnum(1));
        }
        try {
            IRubyObject result = rubyApi.callMethod(recv, "execute", args);
            return rubyApi.callMethod(result, "first");
        } finally {
            rubyApi.setInstanceVariable(recv, "@limit", recv.getRuntime().getNil());
        }
    }

    @JRubyMethod(name = "_execute", required = 1, optional = 1)
    public static IRubyObject _execute(ThreadContext context, IRubyObject recv, IRubyObject[] args) throws SQLException, java.io.IOException {
        Ruby runtime = recv.getRuntime();
        RubyJdbcConnection conn = (RubyJdbcConnection) rubyApi.getInstanceVariable(recv, "@connection");
        String sql = args[0].toString().trim().toLowerCase();
        if (sql.charAt(0) == '(') {
            sql = sql.substring(1).trim();
        }
        if (sql.startsWith("insert")) {
            return conn.execute_insert(context, args[0]);
        } else if (sql.startsWith("select") || sql.startsWith("show") || sql.startsWith("values")) {
            return conn.execute_query(context, args[0]);
        } else {
            return conn.execute_update(context, args[0]);
        }
    }
}
