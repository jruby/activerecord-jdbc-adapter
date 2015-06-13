/*
 * The MIT License
 *
 * Copyright 2015 Karol Bucek
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
package arjdbc.postgresql;

/**
 * Based on JDBC PostgreSQL driver's <code>org.postgresql.util.PGbytea</code>.
 *
 * @author kares
 */
abstract class ByteaUtils {

    //static byte[] toBytes(final byte[] s) {
    //    return toBytes(s, 0, s.length);
    //}

    /*
     * Converts a PG bytea raw value (i.e. the raw binary representation
     * of the bytea data type) into a java byte[]
     */
    static byte[] toBytes(final byte[] s, final int off, final int len) {
        // Starting with PG 9.0, a new hex format is supported
        // that starts with "\x".  Figure out which format we're
        // dealing with here.
        //
        if ( s.length < 2 || s[0] != '\\' || s[1] != 'x' ) {
            return toBytesOctalEscaped(s, off, len);
        }
        return toBytesHexEscaped(s, off, len);
    }

    private static byte[] toBytesHexEscaped(final byte[] s, final int off, final int len) {
        final byte[] out = new byte[(len - 2) / 2];
        for (int i = 0; i < out.length; i++) {
            final int j = off + (2 + i * 2);
            byte b1 = hexByte( s[j] );
            byte b2 = hexByte( s[j + 1] );
            out[i] = (byte) ((b1 << 4) | b2);
        }
        return out;
    }

    private static byte hexByte(final byte b) {
        // 0-9 == 48-57
        if (b <= 57) return (byte) (b - 48);

        // a-f == 97-102
        if (b >= 97) return (byte) (b - 97 + 10);

        // A-F == 65-70
        return (byte) (b - 65 + 10);
    }

    private static final int MAX_3_BUFF_SIZE = 2 * 1024 * 1024;

    private static byte[] toBytesOctalEscaped(final byte[] s, final int off, final int len) {
        final byte[] out;
        final int end = off + len;
        int correctSize = len;
        if ( len > MAX_3_BUFF_SIZE ) {
            // count backslash escapes, they will be either
            // backslashes or an octal escape \\ or \003
            //
            for ( int i = off; i < end; ++i ) {
                if ( s[i] == '\\' ) {
                    byte next = s[ ++i ];
                    if (next == '\\') {
                        --correctSize;
                    }
                    else {
                        correctSize -= 3;
                    }
                }
            }
            out = new byte[correctSize];
        }
        else {
            out = new byte[len];
        }

        int pos = 0;
        for ( int i = off; i < end; i++ ) {
            final byte b = s[i];
            if ( b == (byte) '\\' ) {
                final byte b1 = s[++i];
                if ( b1 == (byte) '\\' ) { // escaped \
                    out[ pos++ ] = (byte) '\\';
                }
                else {
                    int thebyte = (b1 - 48) * 64 + (s[++i] - 48) * 8 + (s[++i] - 48);
                    if ( thebyte > 127 ) thebyte -= 256;
                    out[ pos++ ] = (byte) thebyte;
                }
            }
            else {
                out[ pos++ ] = b;
            }
        }

        if ( pos == correctSize ) return out;

        final byte[] out2 = new byte[pos];
        System.arraycopy(out, 0, out2, 0, pos);
        return out2;
    }

    /*
     * Converts a java byte[] into a PG bytea string (i.e. the text
     * representation of the bytea data type)
     */
    /*
    public static String toPGString(byte[] p_buf)  {
        if (p_buf == null)
            return null;
        StringBuffer l_strbuf = new StringBuffer(2 * p_buf.length);
        for (int i = 0; i < p_buf.length; i++)
        {
            int l_int = (int)p_buf[i];
            if (l_int < 0)
            {
                l_int = 256 + l_int;
            }
            //we escape the same non-printable characters as the backend
            //we must escape all 8bit characters otherwise when convering
            //from java unicode to the db character set we may end up with
            //question marks if the character set is SQL_ASCII
            if (l_int < 040 || l_int > 0176)
            {
                //escape charcter with the form \000, but need two \\ because of
                //the Java parser
                l_strbuf.append("\\");
                l_strbuf.append((char)(((l_int >> 6) & 0x3) + 48));
                l_strbuf.append((char)(((l_int >> 3) & 0x7) + 48));
                l_strbuf.append((char)((l_int & 0x07) + 48));
            }
            else if (p_buf[i] == (byte)'\\')
            {
                //escape the backslash character as \\, but need four \\\\ because
                //of the Java parser
                l_strbuf.append("\\\\");
            }
            else
            {
                //other characters are left alone
                l_strbuf.append((char)p_buf[i]);
            }
        }
        return l_strbuf.toString();
    } */

}
