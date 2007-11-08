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

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.RubyFloat;
import org.jruby.RubyFixnum;
import org.jruby.RubyBignum;
import org.jruby.RubyBoolean;
import org.jruby.RubyBigDecimal;
import org.jruby.RubyRange;
import org.jruby.RubyNumeric;

import org.jruby.runtime.Arity;
import org.jruby.runtime.CallbackFactory;
import org.jruby.runtime.MethodIndex;
import org.jruby.runtime.builtin.IRubyObject;

import org.jruby.util.ByteList;

import java.sql.SQLException;

public class JdbcDerbySpec {
    public static void load(Ruby runtime, RubyModule jdbcSpec) {
        RubyModule derby = jdbcSpec.defineModuleUnder("Derby");
        CallbackFactory cf = runtime.callbackFactory(JdbcDerbySpec.class);
        derby.defineFastMethod("quote_string",cf.getFastSingletonMethod("quote_string",IRubyObject.class));
        derby.defineFastMethod("quote",cf.getFastOptSingletonMethod("quote"));
        derby.defineFastMethod("_execute",cf.getFastOptSingletonMethod("_execute"));
        derby.defineFastMethod("add_limit_offset!",cf.getFastSingletonMethod("add_limit_offset", IRubyObject.class, IRubyObject.class));
        derby.defineFastMethod("select_all",cf.getFastOptSingletonMethod("select_all"));
        derby.defineFastMethod("select_one",cf.getFastOptSingletonMethod("select_one"));
        RubyModule col = derby.defineModuleUnder("Column");
        col.defineFastMethod("type_cast",cf.getFastSingletonMethod("type_cast", IRubyObject.class));
    }

    /*
     * JdbcSpec::Derby::Column.type_cast(value)
     */
    public static IRubyObject type_cast(IRubyObject recv, IRubyObject value) {
        Ruby runtime = recv.getRuntime();

        if(value.isNil() || ((value instanceof RubyString) && value.toString().trim().equalsIgnoreCase("null"))) {
            return runtime.getNil();
        }

        String type = recv.getInstanceVariable("@type").toString();

        switch(type.charAt(0)) {
        case 's': //string
            return value;
        case 't': //text, timestamp, time
            if(type.equals("text")) {
                return value;
            } else {
                return recv.callMethod(runtime.getCurrentContext(), "cast_to_time", value);
            }
        case 'i': //integer
        case 'p': //primary key
            if(value.respondsTo("to_i")) {
                return value.callMethod(runtime.getCurrentContext(), "to_i");
            } else {
                return runtime.newFixnum( value.isTrue() ? 1 : 0 );
            }
        case 'd': //decimal, datetime, date
            if(type.equals("datetime")) {
                return recv.callMethod(runtime.getCurrentContext(), "cast_to_date_or_time", value);
            } else if(type.equals("date")) {
                return recv.getMetaClass().callMethod(runtime.getCurrentContext(), "string_to_date", value);
            } else {
                return recv.getMetaClass().callMethod(runtime.getCurrentContext(), "value_to_decimal", value);
            }
        case 'f': //float
            return value.callMethod(runtime.getCurrentContext(),"to_f");
        case 'b': //binary, boolean
            if(type.equals("binary")) {
                return recv.callMethod(runtime.getCurrentContext(), "value_to_binary", value);
            } else {
                return recv.getMetaClass().callMethod(runtime.getCurrentContext(), "value_to_boolean", value);
            }
        }
        return value;
    }

    public static IRubyObject quote(IRubyObject recv, IRubyObject[] args) {
        Ruby runtime = recv.getRuntime();
        Arity.checkArgumentCount(runtime, args, 1, 2);
        IRubyObject value = args[0];
        if(args.length > 1) {
            IRubyObject col = args[1];
            IRubyObject type = col.callMethod(runtime.getCurrentContext(),"type");
            if(value instanceof RubyString) {
                if(type == runtime.newSymbol("string")) {
                    return quote_string_with_surround(runtime, "'", (RubyString)value, "'");
                } else if(type == runtime.newSymbol("text")) {
                    return quote_string_with_surround(runtime, "CAST('", (RubyString)value, "' AS CLOB)");
                } else if(type == runtime.newSymbol("binary")) {
                    return hexquote_string_with_surround(runtime, "CAST('", (RubyString)value, "' AS BLOB)");
                } else {
                    // column type :integer or other numeric or date version
                    if(only_digits((RubyString)value)) {
                        return value;
                    } else {
                        return super_quote(recv, runtime, value, col);
                    }
                }
            } else if((value instanceof RubyFloat) || (value instanceof RubyFixnum) || (value instanceof RubyBignum)) {
                if(type == runtime.newSymbol("string")) {
                    return quote_string_with_surround(runtime, "'", RubyString.objAsString(value), "'");
                }
            }
        } 
        return super_quote(recv, runtime, value, runtime.getNil());
    }

    private final static ByteList NULL = new ByteList("NULL".getBytes());

    public static IRubyObject super_quote(IRubyObject recv, Ruby runtime, IRubyObject value, IRubyObject col) {
        if(value.respondsTo("quoted_id")) {
            return value.callMethod(runtime.getCurrentContext(), "quoted_id");
        }
        
        IRubyObject type = (col.isNil()) ? col : col.callMethod(runtime.getCurrentContext(),"type");
        if(value instanceof RubyString || 
           value.isKindOf((RubyModule)(((RubyModule)((RubyModule)runtime.getModule("ActiveSupport")).getConstant("Multibyte")).getConstantAt("Chars")))) {
            RubyString svalue = RubyString.objAsString(value);
            if(type == runtime.newSymbol("binary") && col.getType().respondsTo("string_to_binary")) {
                return quote_string_with_surround(runtime, "'", (RubyString)(col.getType().callMethod(runtime.getCurrentContext(), "string_to_binary", svalue)), "'"); 
            } else if(type == runtime.newSymbol("integer") || type == runtime.newSymbol("float")) {
                return RubyString.objAsString(((type == runtime.newSymbol("integer")) ? 
                                               svalue.callMethod(runtime.getCurrentContext(), "to_i") : 
                                               svalue.callMethod(runtime.getCurrentContext(), "to_f")));
            } else {
                return quote_string_with_surround(runtime, "'", svalue, "'"); 
            }
        } else if(value.isNil()) {
            return runtime.newStringShared(NULL);
        } else if(value instanceof RubyBoolean) {
            return (value.isTrue() ? 
                    (type == runtime.newSymbol(":integer")) ? runtime.newString("1") : recv.callMethod(runtime.getCurrentContext(),"quoted_true") :
                    (type == runtime.newSymbol(":integer")) ? runtime.newString("0") : recv.callMethod(runtime.getCurrentContext(),"quoted_false"));
        } else if((value instanceof RubyFloat) || (value instanceof RubyFixnum) || (value instanceof RubyBignum)) {
            return RubyString.objAsString(value);
        } else if(value instanceof RubyBigDecimal) {
            return value.callMethod(runtime.getCurrentContext(), "to_s", runtime.newString("F"));
        } else if(value.isKindOf(runtime.getModule("Date"))) {
            return quote_string_with_surround(runtime, "'", RubyString.objAsString(value), "'"); 
        } else if(value.isKindOf(runtime.getModule("Time")) || value.isKindOf(runtime.getModule("DateTime"))) {
            return quote_string_with_surround(runtime, "'", (RubyString)(recv.callMethod(runtime.getCurrentContext(), "quoted_date", value)), "'"); 
        } else {
            return quote_string_with_surround(runtime, "'", (RubyString)(value.callMethod(runtime.getCurrentContext(), "to_yaml")), "'");
        }
    }

    private final static ByteList TWO_SINGLE = new ByteList(new byte[]{'\'','\''});

    public static IRubyObject quote_string_with_surround(Ruby runtime, String before, RubyString string, String after) {
        ByteList input = string.getByteList();
        ByteList output = new ByteList(before.getBytes());
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

        return runtime.newStringShared(output);
    }

    private final static byte[] HEX = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};

    public static IRubyObject hexquote_string_with_surround(Ruby runtime, String before, RubyString string, String after) {
        ByteList input = string.getByteList();
        ByteList output = new ByteList(before.getBytes());
        for(int i = input.begin; i< input.begin + input.realSize; i++) {
            byte b1 = input.bytes[i];
            byte higher = HEX[(((char)b1)>>4)%16];
            byte lower = HEX[((char)b1)%16];
            if(b1 == '\'') {
                output.append(higher);
                output.append(lower);
            }
            output.append(higher);
            output.append(lower);
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

    public static IRubyObject select_all(IRubyObject recv, IRubyObject[] args) {
        return recv.callMethod(recv.getRuntime().getCurrentContext(),"execute",args);
    }

    public static IRubyObject select_one(IRubyObject recv, IRubyObject[] args) {
        IRubyObject limit = recv.getInstanceVariable("@limit");
        if(limit == null || limit.isNil()) {
            recv.setInstanceVariable("@limit", recv.getRuntime().newFixnum(1));
        }
        try {
            return recv.callMethod(recv.getRuntime().getCurrentContext(),"execute",args).callMethod(recv.getRuntime().getCurrentContext(), "first");
        } finally {
            recv.setInstanceVariable("@limit", recv.getRuntime().getNil());
        }
    }

    public static IRubyObject add_limit_offset(IRubyObject recv, IRubyObject sql, IRubyObject options) {
        recv.setInstanceVariable("@limit", options.callMethod(recv.getRuntime().getCurrentContext(), MethodIndex.AREF, "[]", recv.getRuntime().newSymbol("limit")));
        return recv.setInstanceVariable("@offset", options.callMethod(recv.getRuntime().getCurrentContext(), MethodIndex.AREF, "[]", recv.getRuntime().newSymbol("offset")));
    }

    public static IRubyObject _execute(IRubyObject recv, IRubyObject[] args) throws SQLException, java.io.IOException {
        Ruby runtime = recv.getRuntime();
        try {
            IRubyObject conn = recv.getInstanceVariable("@connection");
            String sql = args[0].toString().trim().toLowerCase();
            if(sql.charAt(0) == '(') {
                sql = sql.substring(1).trim();
            }
            if(sql.startsWith("insert")) {
                return JdbcAdapterInternalService.execute_insert(conn, args[0]);
            } else if(sql.startsWith("select") || sql.startsWith("show")) {
                IRubyObject offset = recv.getInstanceVariable("@offset");
                if(offset == null || offset.isNil()) {
                    offset = RubyFixnum.zero(runtime);
                }
                IRubyObject limit = recv.getInstanceVariable("@limit");
                IRubyObject range;
                IRubyObject max;
                if(limit == null || limit.isNil() || RubyNumeric.fix2int(limit) == -1) {
                    range = RubyRange.newRange(runtime, offset, runtime.newFixnum(-1), false);
                    max = RubyFixnum.zero(runtime);
                } else {
                    IRubyObject v1 = offset.callMethod(runtime.getCurrentContext(), MethodIndex.OP_PLUS, "+", limit);
                    range = RubyRange.newRange(runtime, offset, v1, true);
                    max = v1.callMethod(runtime.getCurrentContext(), MethodIndex.OP_PLUS, "+", RubyFixnum.one(runtime));
                }
                IRubyObject ret = JdbcAdapterInternalService.execute_query(conn, new IRubyObject[]{args[0], max}).
                    callMethod(runtime.getCurrentContext(), MethodIndex.AREF, "[]", range);
                if(ret.isNil()) {
                    return runtime.newArray();
                } else {
                    return ret;
                }
            } else {
                return JdbcAdapterInternalService.execute_update(conn, args[0]);
            }
        } finally {
            recv.setInstanceVariable("@limit",runtime.getNil());
            recv.setInstanceVariable("@offset",runtime.getNil());
        }
    }
}
