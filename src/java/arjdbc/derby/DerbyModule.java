/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2013 Karol Bucek <self@kares.org>
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

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
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

    @JRubyMethod(name = "quote_binary", required = 1)
    public static IRubyObject quote_binary(final ThreadContext context,
        final IRubyObject self, final IRubyObject string) {
        return quoteStringHex(context.getRuntime(), "", string, "");
    }

    private final static byte[] HEX = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};

    private static IRubyObject quoteStringHex(final Ruby runtime,
        final String before, final IRubyObject string, final String after) {

        final ByteList input = ((RubyString) string).getByteList();
        final int size = input.getRealSize();
        final ByteList output = new ByteList( before.length() + size * 2 + after.length() );
        output.append( before.getBytes() );

        final byte[] inputBytes = input.unsafeBytes();

        int written = 0;
        for (int i = input.getBegin(); i < input.getBegin() + size; i++) {
            final byte b = inputBytes[i];
            byte h = HEX[ ( ((char) b) >> 4 ) % 16 ];
            byte l = HEX[ ( (char) b ) % 16 ];
            output.append(h).append(l);
            written += 2;
            if ( written >= 16334 ) { // max hex length = 16334
                output.append("'||X'".getBytes());
                written = 0;
            }
        }

        output.append( after.getBytes() );
        return RubyString.newStringShared(runtime, output);
    }

    @JRubyMethod(name = "quote_string", required = 1)
    public static IRubyObject quote_string(final IRubyObject self, IRubyObject string) {
        if ( ! ( string instanceof RubyString ) ) {
            string = string.asString(); // e.g. Multibyte::Chars
        }

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
        final ThreadContext context, final IRubyObject self) {
        return RubyString.newString(context.getRuntime(), BYTES_1);
    }

    @JRubyMethod(name = "quoted_false", required = 0, frame = false)
    public static IRubyObject quoted_false(
        final ThreadContext context, final IRubyObject self) {
        return RubyString.newString(context.getRuntime(), BYTES_0);
    }

    private static RubyModule getMultibyteChars(final Ruby runtime) {
        return (RubyModule) ((RubyModule) runtime.getModule("ActiveSupport").
                getConstant("Multibyte")).getConstantAt("Chars");
    }

}
