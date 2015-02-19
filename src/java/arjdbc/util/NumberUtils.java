/*
 * The MIT License
 *
 * Copyright 2015 Karol Bucek.
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

import org.jruby.util.ByteList;

/**
 *
 * @author kares
 */
public abstract class NumberUtils {

    public static ByteList appendLong(final long value, final ByteList bytes) {
        final String str = Long.toString(value);
        for ( int i = 0; i < str.length(); i++ ) {
            bytes.append( str.charAt(i) );
        }
        return bytes;
    }

    public static ByteList appendInteger(final int value, final ByteList bytes) {
        final String str = Integer.toString(value);
        for ( int i = 0; i < str.length(); i++ ) {
            bytes.append( str.charAt(i) );
        }
        return bytes;
    }

}
