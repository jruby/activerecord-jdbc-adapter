/*
 * The MIT License
 *
 * Copyright 2013 Karol Bucek.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package arjdbc.util;

import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 * Shared (common) quoting helpers.
 *
 * <br>
 * NOTE: This is internal API !
 * <br>
 *
 * @author kares
 */
public abstract class QuotingUtils {

    public static final ByteList BYTES_0 = new ByteList(new byte[] { '0' }, false);

    public static final ByteList BYTES_1 = new ByteList(new byte[] { '1' }, false);

    // e.g. string.gsub("'", "''") -> quoteCharWith(string, '\'', '\'');
    public static RubyString quoteCharWith(
            final ThreadContext context,
            final RubyString string,
            final char value, final char quote) {
        return quoteCharWith(context, string, value, quote, 0, 8);
    }

    @SuppressWarnings("deprecation")
    public static RubyString quoteCharWith(
            final ThreadContext context,
            final RubyString string,
            final char value, final char quote,
            final int newOffset, final int newSizeDiff) {

        final ByteList stringBytes = string.getByteList();
        final byte[] bytes = stringBytes.unsafeBytes();
        final int begin = stringBytes.getBegin();
        final int realSize = stringBytes.getRealSize();

        ByteList quotedBytes = null; int appendFrom = begin;
        for ( int i = begin; i < begin + realSize; i++ ) {
            if ( bytes[i] == value ) {
                if ( quotedBytes == null ) {
                    quotedBytes = new ByteList(
                        new byte[realSize + newOffset + newSizeDiff],
                        stringBytes.getEncoding(), false
                    );
                    quotedBytes.begin = newOffset;
                    quotedBytes.realSize = 0;
                }
                quotedBytes.append(bytes, appendFrom, i - appendFrom);
                quotedBytes.append(quote).append(value); // e.g. "'" => "''"
                appendFrom = i + 1;
            }
        }
        if ( quotedBytes != null ) { // append what's left in the end :
            quotedBytes.append(bytes, appendFrom, begin + realSize - appendFrom);
        }
        else return string; // nothing changed, can return original

        return context.getRuntime().newString(quotedBytes);
    }

    public static final ByteList BYTES_SINGLE_Q = new ByteList(new byte[] { '\'' }, false);
    public static final ByteList BYTES_SINGLE_Q_x2 = new ByteList(new byte[] { '\'', '\'' }, false);

    // string.gsub("'", "''") :
    public static IRubyObject quoteSingleQuotesWithFallback(
        final ThreadContext context, final IRubyObject string) {
        // string.gsub("'", "''") :
        if ( string instanceof RubyString ) {
            final char single = '\'';
            return quoteCharWith(context, (RubyString) string, single, single);
        }
        else { // ActiveSupport::Multibyte::Chars
            return string.callMethod(context, "gsub",
                new IRubyObject[] {
                    context.getRuntime().newString(BYTES_SINGLE_Q),
                    context.getRuntime().newString(BYTES_SINGLE_Q_x2)
                }
            );
        }
    }

}
