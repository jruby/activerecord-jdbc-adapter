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

import static arjdbc.util.QuotingUtils.BYTES_0;
import static arjdbc.util.QuotingUtils.BYTES_1;
import static arjdbc.util.QuotingUtils.BYTES_SINGLE_Q_x2;

import arjdbc.jdbc.RubyJdbcConnection;

import java.sql.SQLException;

import org.jruby.Ruby;
import org.jruby.RubyBoolean;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

public class DerbyModule {

    public static RubyModule load(final RubyModule arJdbc) {
        RubyModule derby = arJdbc.defineModuleUnder("Derby");
        derby.defineAnnotatedMethods( DerbyModule.class );
        RubyModule column = derby.defineModuleUnder("Column");
        column.defineAnnotatedMethods(Column.class);
        return derby;
    }

    public static class Column {

        @JRubyMethod(name = "type_cast", required = 1)
        public static IRubyObject type_cast(final ThreadContext context,
            final IRubyObject self, final IRubyObject value) {

            if ( value.isNil() ||
            ( (value instanceof RubyString) && value.toString().trim().equalsIgnoreCase("null") ) ) {
                return context.getRuntime().getNil();
            }

            final String type = self.getInstanceVariables().getInstanceVariable("@type").toString();

            switch (type.charAt(0)) {
            case 's': //string
                return value;
            case 't': //text, timestamp, time
                if ( type.equals("time") ) {
                    return self.getMetaClass().callMethod(context, "string_to_dummy_time", value);
                }
                if ( type.equals("timestamp") ) {
                    return self.getMetaClass().callMethod(context, "string_to_time", value);
                }
                return value; // text
            case 'i': //integer
            case 'p': //primary key
                if ( value.respondsTo("to_i") ) {
                    return value.callMethod(context, "to_i");
                }
                return context.getRuntime().newFixnum( value.isTrue() ? 1 : 0 );
            case 'd': //decimal, datetime, date
                if ( type.equals("datetime") ) {
                    return self.getMetaClass().callMethod(context, "string_to_time", value);
                }
                if ( type.equals("date") ) {
                    return self.getMetaClass().callMethod(context, "string_to_date", value);
                }
                return self.getMetaClass().callMethod(context, "value_to_decimal", value);
            case 'f': //float
                return value.callMethod(context, "to_f");
            case 'b': //binary, boolean
                return type.equals("binary") ?
                    self.getMetaClass().callMethod(context, "binary_to_string", value) :
                    self.getMetaClass().callMethod(context, "value_to_boolean", value) ;
            }
            return value;
        }

    }

    @JRubyMethod(name = "quote", required = 1, optional = 1)
    public static IRubyObject quote(final ThreadContext context,
        final IRubyObject self, final IRubyObject[] args) {
        final Ruby runtime = self.getRuntime();
        IRubyObject value = args[0];
        if ( args.length > 1 ) {
            final IRubyObject column = args[1];
            final String columnType = column.isNil() ? "" : column.callMethod(context, "type").toString();
            // intercept and change value, maybe, if the column type is :text or :string
            if ( columnType.equals("text") || columnType.equals("string") ) {
            	value = toRubyStringForTextColumn(context, runtime, self, value);
            }

            if ( value instanceof RubyString ) {
                if ( columnType.equals("string") ) {
                    return quoteString(runtime, "'", value, "'");
                }
                if ( columnType.equals("text") ) {
                    return quoteString(runtime, "CAST('", value, "' AS CLOB)");
                }
                if ( columnType.equals("binary") ) {
                    return quoteStringHex(runtime, "CAST(X'", value, "' AS BLOB)");
                }
                if ( columnType.equals("xml") ) {
                    return quoteString(runtime, "XMLPARSE(DOCUMENT '", value, "' PRESERVE WHITESPACE)");
                }
                // column type :integer or other numeric or date version
                return isDigitsOnly(value) ? value : quoteDefault(context, runtime, self, value, column, columnType);
            }

            final String metaClass = value.getMetaClass().getName();
            if ( metaClass.equals("Float") || metaClass.equals("Fixnum") || metaClass.equals("Bignum") ) {
                if ( columnType.equals("string") ) {
                    return quoteString(runtime, "'", RubyString.objAsString(context, value), "'");
                }
            }
        }
        return quoteDefault(context, runtime, self, value, runtime.getNil(), null);
    }

    private static IRubyObject quoted_date_OR_to_yaml(final ThreadContext context,
        final Ruby runtime, final IRubyObject self, final IRubyObject value) {

        if ( value.callMethod(context, "acts_like?", runtime.newSymbol("date")).isTrue()
          || value.callMethod(context, "acts_like?", runtime.newSymbol("time")).isTrue() ) {
            return self.callMethod(context, "quoted_date", value);
        }
        else {
            return value.callMethod(context, "to_yaml");
        }
    }

    /*
     * Derby is not permissive like MySql. Try and send an Integer to a CLOB or
     * VARCHAR column and Derby will vomit.
     * This method turns non stringy things into strings.
     */
    private static IRubyObject toRubyStringForTextColumn(
        final ThreadContext context, final Ruby runtime, final IRubyObject self,
        final IRubyObject value) {

        if ( value instanceof RubyString || value.isNil() || isMultibyteChars(runtime, value) ) {
            return value;
        }

        if ( value instanceof RubyBoolean ) return quoteBoolean(runtime, value);

        final String className = value.getMetaClass().getName();
        if ( className.equals("Float") || className.equals("Fixnum") || className.equals("Bignum") ) {
            return RubyString.objAsString(context, value);
        }
        if ( className.equals("BigDecimal") ) {
            return value.callMethod(context, "to_s", runtime.newString("F"));
        }

        return quoted_date_OR_to_yaml(context, runtime, self, value);
    }

    private final static ByteList NULL = new ByteList("NULL".getBytes(), false);

    private static IRubyObject quoteDefault(final ThreadContext context,
        final Ruby runtime, final IRubyObject self,
        final IRubyObject value, final IRubyObject column, final String columnType) {

        if ( value.respondsTo("quoted_id") ) {
            return value.callMethod(context, "quoted_id");
        }

        if ( value.isNil() ) {
            return runtime.newString(NULL);
        }
        if ( value instanceof RubyBoolean ) {
            if ( columnType == (Object) "integer" ) return quoteBoolean(runtime, value);
            return self.callMethod(context, value.isTrue() ? "quoted_true" : "quoted_false");
        }
        if ( value instanceof RubyString || isMultibyteChars(runtime, value) ) {

            final RubyString strValue = RubyString.objAsString(context, value);

            if ( columnType == (Object) "binary" && column.getType().respondsTo("string_to_binary") ) {
                IRubyObject str = column.getType().callMethod(context, "string_to_binary", strValue);
                return quoteString(runtime, "'", str, "'");
            }

            if ( columnType == (Object) "integer" ) {
                return RubyString.objAsString( context, strValue.callMethod(context, "to_i") );
            }

            if ( columnType == (Object) "float" ) {
                return RubyString.objAsString( context, strValue.callMethod(context, "to_f") );
            }

            return quoteString(runtime, "'", strValue, "'");
        }

        final String className = value.getMetaClass().getName();
        if ( className.equals("Float") || className.equals("Fixnum") || className.equals("Bignum") ) {
            return RubyString.objAsString(context, value);
        }
        if ( className.equals("BigDecimal") ) {
            return value.callMethod(context, "to_s", runtime.newString("F"));
        }

        IRubyObject strValue = quoted_date_OR_to_yaml(context, runtime, self, value);
        return quoteString(runtime, "'", strValue, "'");
    }

    private static IRubyObject quoteString(final Ruby runtime,
        final String before, final IRubyObject string, final String after) {

        final ByteList input = ((RubyString) string).getByteList();
        final ByteList output = new ByteList(before.getBytes(), input.getEncoding());
        final byte[] inputBytes = input.unsafeBytes();

        for(int i = input.getBegin(); i< input.getBegin() + input.getRealSize(); i++) {
            switch ( inputBytes[i] ) {
                case '\'': output.append(inputBytes[i]); // FALLTHROUGH
                default: output.append(inputBytes[i]);
            }

        }

        output.append(after.getBytes());
        return runtime.newString(output);
    }

    private final static byte[] HEX = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};

    private static IRubyObject quoteStringHex(final Ruby runtime,
        final String before, final IRubyObject string, final String after) {

        final ByteList input = ((RubyString) string).getByteList();
        final ByteList output = new ByteList(before.getBytes());
        final byte[] inputBytes = input.unsafeBytes();

        int written = 0;
        for(int i = input.getBegin(); i< input.getBegin() + input.getRealSize(); i++) {
            byte b1 = inputBytes[i];
            byte higher = HEX[(((char)b1)>>4)%16];
            byte lower = HEX[((char)b1)%16];
            output.append(higher);
            output.append(lower);
            written += 2;
            if (written >= 16334) { // max hex length = 16334
                output.append("'||X'".getBytes());
                written = 0;
            }
        }

        output.append(after.getBytes());
        return RubyString.newStringShared(runtime, output);
    }

    private static boolean isDigitsOnly(final IRubyObject string) {
        final ByteList input = ((RubyString) string).getByteList();
        final byte[] inputBytes = input.unsafeBytes();
        for ( int i = input.getBegin(); i< input.getBegin() + input.getRealSize(); i++ ) {
            if ( inputBytes[i] < '0' || inputBytes[i] > '9' ) {
                return false;
            }
        }
        return true;
    }

    private static boolean isMultibyteChars(final Ruby runtime, final IRubyObject value) {
        return getMultibyteChars(runtime).isInstance(value);
    }

    @JRubyMethod(name = "quote_string", required = 1)
    public static IRubyObject quote_string(final IRubyObject self, IRubyObject string) {
        ByteList bytes = ((RubyString) string).getByteList();

        boolean replacement = false;
        for ( int i = 0; i < bytes.length(); i++ ) {
            switch ( bytes.get(i) ) {
                case '\'': break;
                default: continue;
            }
            // on first replacement allocate so we don't manip original
            if ( ! replacement ) {
                bytes = new ByteList(bytes);
                replacement = true;
            }

            bytes.replace(i, 1, BYTES_SINGLE_Q_x2);
            i += 1;
        }

        return replacement ? RubyString.newStringShared(self.getRuntime(), bytes) : string;
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

    private static RubyString quoteBoolean(final Ruby runtime, final IRubyObject value) {
        return value.isTrue() ? runtime.newString(BYTES_1) : runtime.newString(BYTES_0);
    }

    @JRubyMethod(name = "_execute", required = 1, optional = 1)
    public static IRubyObject _execute(final ThreadContext context, final IRubyObject self, final IRubyObject[] args)
        throws SQLException {
        final IRubyObject sql = args[0];

        String sqlStr = sql.toString().trim();
        if ( sqlStr.charAt(0) == '(' ) sqlStr = sqlStr.substring(1).trim();
        sqlStr = sqlStr.substring( 0, Math.min(6, sqlStr.length()) ).toLowerCase();

        final RubyJdbcConnection connection = (RubyJdbcConnection)
            self.getInstanceVariables().getInstanceVariable("@connection");

        if (sqlStr.startsWith("insert")) {
            return connection.execute_insert(context, sql);
        }
        else if (sqlStr.startsWith("select") || sqlStr.startsWith("show") || sqlStr.startsWith("values")) {
            return connection.execute_query_raw(context, sql, Block.NULL_BLOCK);
        }
        else {
            return connection.execute_update(context, sql);
        }
    }

    private static RubyModule getMultibyteChars(final Ruby runtime) {
        return (RubyModule) ((RubyModule) runtime.getModule("ActiveSupport").
                getConstant("Multibyte")).getConstantAt("Chars");
    }

}
