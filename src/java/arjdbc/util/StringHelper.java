/*
 * The MIT License
 *
 * Copyright 2014 Karol Bucek.
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

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.Charset;

import org.jcodings.Encoding;
import org.jcodings.specific.UTF8Encoding;
import org.jruby.Ruby;
import org.jruby.RubyEncoding;
import org.jruby.RubyString;
import org.jruby.util.ByteList;

/**
 * Some (Ruby) byte string helpers.
 *
 * @author kares
 */
public abstract class StringHelper {

    public static byte decByte(final int digit) {
        switch (digit) {
            case 0 : return '0';
            case 1 : return '1';
            case 2 : return '2';
            case 3 : return '3';
            case 4 : return '4';
            case 5 : return '5';
            case 6 : return '6';
            case 7 : return '7';
            case 8 : return '8';
            case 9 : return '9';
        }
        throw new IllegalStateException("unexpected digit: " + digit);
    }

    public static RubyString newString(final Ruby runtime, final byte[] bytes) {
        return RubyString.newString(runtime, new ByteList(bytes, false));
    }

    private static final Charset ASCII_CHARSET = Charset.forName("ISO-8859-1");

    public static RubyString newASCIIString(final Ruby runtime, final String str) {
        final ByteList byteList = new ByteList(str.getBytes(ASCII_CHARSET), false);
        return RubyString.newString(runtime, byteList);
    }

    public static RubyString newUTF8String(final Ruby runtime, final byte[] bytes) {
        final ByteList byteList = new ByteList(bytes, false);
        return RubyString.newString(runtime, byteList, UTF8Encoding.INSTANCE);
    }

    public static RubyString newDefaultInternalString(final Ruby runtime, final byte[] bytes) {
        final ByteList byteList = new ByteList(bytes, false);
        Encoding enc = runtime.getDefaultInternalEncoding();
        if (enc == null) enc = runtime.getEncodingService().getJavaDefault();
        return RubyString.newString(runtime, byteList, enc);
    }

    public static RubyString newDefaultInternalString(final Ruby runtime, final CharSequence str) {
        Encoding enc = runtime.getDefaultInternalEncoding();
        if (enc == null) enc = runtime.getEncodingService().getJavaDefault();
        return RubyString.newString(runtime, new ByteList(RubyEncoding.encode(str, enc.getCharset()), enc));
    }

    public static RubyString newDefaultInternalString(final Ruby runtime, final String str) {
        return RubyString.newInternalFromJavaExternal(runtime, str);
    }

    public static int readBytes(final ByteList output, final InputStream input)
        throws IOException {
        @SuppressWarnings("deprecation") // capacity :
        final int buffSize = output.bytes.length - output.begin;
        return readBytes(output, input, buffSize);
    }

    public static int readBytes(final ByteList output, final InputStream input, int buffSize)
        throws IOException {
        int read = 0;
        while ( true ) {
            output.ensure( output.getRealSize() + buffSize );
            final int begin = output.getBegin();
            final int size = output.getRealSize();
            int n = input.read(output.unsafeBytes(), begin + size, buffSize);
            if ( n == -1 ) break;
            output.setRealSize( size + n ); read += n;
        }
        return read;
    }

    public static boolean startsWithIgnoreCase(final ByteList bytes, final byte[] start) {
        int p = nonWhitespaceIndex(bytes, bytes.getBegin());
        final byte[] stringBytes = bytes.unsafeBytes();
        if ( stringBytes[p] == '(' ) {
            p = nonWhitespaceIndex(bytes, p + 1);
        }

        for ( int i = 0; i < bytes.getRealSize() && i < start.length; i++ ) {
            if ( Character.toLowerCase(stringBytes[p + i]) != start[i] ) return false;
        }
        return true;
    }

    public static int nonWhitespaceIndex(final ByteList string, final int off) {
        final int end = string.getBegin() + string.getRealSize();
        final byte[] stringBytes = string.unsafeBytes();
        for ( int i = off; i < end; i++ ) {
            if ( ! Character.isWhitespace( stringBytes[i] ) ) return i;
        }
        return end;
    }

    @SuppressWarnings("deprecation")
    private static int nonSpaceIndex(final byte[] str, int beg, int len) {
        for ( int i = beg; i < len; i++ ) {
            if ( ! Character.isSpace( (char) str[i] ) ) return i;
        }
        return len;
    }

    private static int nonDigitIndex(final byte[] str, int beg, int len) {
        for ( int i = beg; i < len; i++ ) {
            if ( ! Character.isDigit( (char) str[i] ) ) return i;
        }
        return len;
    }

    private static int extractIntValue(final byte[] str, int beg, int end) {
        int n = 0;
        for ( int i = beg; i < end; i++ ) {
            n = 10 * n + ( str[i] - '0' );
        }
        return n;
    }

}
