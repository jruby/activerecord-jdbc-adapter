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
 * Copyright (C) 2007 Ola Bini <ola.bini@gmail.com>
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

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.RubyFloat;
import org.jruby.RubyFixnum;
import org.jruby.RubyBignum;
import org.jruby.RubyBoolean;
import org.jruby.RubyBigDecimal;

import org.jruby.runtime.Arity;
import org.jruby.runtime.CallbackFactory;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.jruby.util.ByteList;

public class JDBCDerbySpec {
    public static void load(Ruby runtime, RubyModule jdbcSpec) {
        RubyModule derby = jdbcSpec.defineModuleUnder("Derby");
        CallbackFactory cf = runtime.callbackFactory(JDBCDerbySpec.class);
        derby.defineFastMethod("quote_string",cf.getFastSingletonMethod("quote_string",IRubyObject.class));
        derby.defineFastMethod("quote",cf.getFastOptSingletonMethod("quote"));
    }

    public static IRubyObject quote(IRubyObject recv, IRubyObject[] args) {
        Ruby runtime = recv.getRuntime();
        Arity.checkArgumentCount(runtime, args, 1, 2);
        IRubyObject value = args[0];
        if(args.length > 1) {
            IRubyObject col = args[1];
            if(value instanceof RubyString) {
                    IRubyObject type = col.callMethod(runtime.getCurrentContext(),"type");
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
                if(col == runtime.newSymbol("string")) {
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
}
