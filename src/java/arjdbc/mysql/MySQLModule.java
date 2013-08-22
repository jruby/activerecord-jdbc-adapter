/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2013 Karol Bucek <self@kares.org>
 * Copyright (c) 2006-2010 Nick Sieger <nick@nicksieger.com>
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

package arjdbc.mysql;

import static arjdbc.util.QuotingUtils.BYTES_0;
import static arjdbc.util.QuotingUtils.BYTES_1;
import static arjdbc.util.QuotingUtils.quoteCharWith;

import org.jcodings.specific.UTF8Encoding;

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

public class MySQLModule {

    public static RubyModule load(final RubyModule arJdbc) {
        RubyModule mysql = arJdbc.defineModuleUnder("MySQL");
        mysql.defineAnnotatedMethods(MySQLModule.class);
        return mysql;
    }

    //private final static byte[] ZERO = new byte[] {'\\','0'};
    //private final static byte[] NEWLINE = new byte[] {'\\','n'};
    //private final static byte[] CARRIAGE = new byte[] {'\\','r'};
    //private final static byte[] ZED = new byte[] {'\\','Z'};
    //private final static byte[] DBL = new byte[] {'\\','"'};
    //private final static byte[] SINGLE = new byte[] {'\\','\''};
    //private final static byte[] ESCAPE = new byte[] {'\\','\\'};

    private static final int STRING_QUOTES_OPTIMISTIC_QUESS = 24;

    @JRubyMethod(name = "quote_string", required = 1, frame = false)
    public static IRubyObject quote_string(final ThreadContext context,
        final IRubyObject recv, final IRubyObject string) {

        final ByteList stringBytes = ((RubyString) string).getByteList();
        final byte[] bytes = stringBytes.unsafeBytes();
        final int begin = stringBytes.getBegin();
        final int realSize = stringBytes.getRealSize();

        ByteList quotedBytes = null; int appendFrom = begin;
        for ( int i = begin; i < begin + realSize; i++ ) {
            final byte byte2;
            switch ( bytes[i] ) {
                case   0  : byte2 = '0';  break;
                case '\n' : byte2 = 'n';  break;
                case '\r' : byte2 = 'r';  break;
                case  26  : byte2 = 'Z';  break;
                case '"'  : byte2 = '"';  break;
                case '\'' : byte2 = '\''; break;
                case '\\' : byte2 = '\\'; break;
                default   : byte2 = 0;
            }
            if ( byte2 != 0 ) {
                if ( quotedBytes == null ) {
                    quotedBytes = new ByteList(
                        new byte[realSize + STRING_QUOTES_OPTIMISTIC_QUESS],
                        stringBytes.getEncoding()
                    );
                    quotedBytes.setBegin(0);
                    quotedBytes.setRealSize(0);
                } // copy string on-first quote we "optimize" for non-quoted
                quotedBytes.append(bytes, appendFrom, i - appendFrom);
                quotedBytes.append('\\').append(byte2);
                appendFrom = i + 1;
            }
        }
        if ( quotedBytes != null ) { // append what's left in the end :
            quotedBytes.append(bytes, appendFrom, begin + realSize - appendFrom);
        }
        else return string; // nothing changed, can return original

        final Ruby runtime = context.getRuntime();
        final RubyString quoted = runtime.newString(quotedBytes);
        if ( runtime.is1_9() ) { // only due mysql2 compatibility
            quoted.associateEncoding( UTF8Encoding.INSTANCE );
        }
        return quoted;
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

    @JRubyMethod(name = "quote_column_name", required = 1, frame = false)
    public static IRubyObject quote_column_name(
            final ThreadContext context,
            final IRubyObject self,
            final IRubyObject string) { // "`#{name.to_s.gsub('`', '``')}`"
        RubyString origin = string.asString();
        RubyString quoted = quoteCharWith(context, origin, '`', '`');
        final ByteList bytes = quoted.getByteList();
        if ( origin == quoted ) {
            final RubyString result =
                RubyString.newStringLight(context.getRuntime(), bytes.getRealSize() + 2, bytes.getEncoding());
            final ByteList resultBytes = result.getByteList();
            resultBytes.append( (byte) '`' );
            resultBytes.append( bytes );
            resultBytes.append( (byte) '`' );
            return result;
        }
        else {
            bytes.append( (byte) '`' );
            bytes.prepend( (byte) '`' );
            return quoted;
        }
    }

}
