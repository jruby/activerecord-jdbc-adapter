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

import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;

import org.joda.time.DateTime;
import org.jruby.RubyClass;
import org.jruby.RubyFloat;
import org.jruby.RubyString;
import org.jruby.RubyTime;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

import static arjdbc.jdbc.RubyJdbcConnection.getBase;
import static arjdbc.util.StringHelper.decByte;
import org.joda.time.DateTimeZone;

/**
 *
 * @author kares
 */
public abstract class DateTimeUtils {

    @SuppressWarnings("deprecation")
    public static ByteList timeToString(final Time time) {
        final ByteList str = new ByteList(8); // hh:mm:ss

        int hours = time.getHours();
        int minutes = time.getMinutes();
        int seconds = time.getSeconds();

        str.append( decByte( hours / 10 ) );
        str.append( decByte( hours % 10 ) );

        str.append( ':' );

        str.append( decByte( minutes / 10 ) );
        str.append( decByte( minutes % 10 ) );

        str.append( ':' );

        str.append( decByte( seconds / 10 ) );
        str.append( decByte( seconds % 10 ) );

        return str;
    }

    @SuppressWarnings("deprecation")
    public static ByteList dateToString(final Date date) {
        final ByteList str = new ByteList(10); // "2000-00-00"

        int year = date.getYear() + 1900;
        int month = date.getMonth() + 1;
        int day = date.getDate();

        str.append( decByte( ( year / 1000 ) % 10 ) );
        str.append( decByte( ( year / 100 ) % 10 ) );
        str.append( decByte( ( year / 10 ) % 10 ) );
        str.append( decByte( year % 10 ) );

        str.append( '-' );

        str.append( decByte( month / 10 ) );
        str.append( decByte( month % 10 ) );

        str.append( '-' );

        str.append( decByte( day / 10 ) );
        str.append( decByte( day % 10 ) );

        return str;
    }

    @SuppressWarnings("deprecation")
    public static ByteList timestampToString(final Timestamp timestamp) {
        final ByteList str = new ByteList(29); // yyyy-mm-dd hh:mm:ss.fffffffff

        int year = timestamp.getYear() + 1900;
        int month = timestamp.getMonth() + 1;
        int day = timestamp.getDate();
        int hours = timestamp.getHours();
        int minutes = timestamp.getMinutes();
        int seconds = timestamp.getSeconds();
        int nanos = timestamp.getNanos();

        str.append( decByte( ( year / 1000 ) % 10 ) );
        str.append( decByte( ( year / 100 ) % 10 ) );
        str.append( decByte( ( year / 10 ) % 10 ) );
        str.append( decByte( year % 10 ) );

        str.append( '-' );

        str.append( decByte( month / 10 ) );
        str.append( decByte( month % 10 ) );

        str.append( '-' );

        str.append( decByte( day / 10 ) );
        str.append( decByte( day % 10 ) );

        if ( hours != 0 || minutes != 0 || seconds != 0 || nanos != 0 ) {
            str.append(' ');

            str.append( decByte( hours / 10 ) );
            str.append( decByte( hours % 10 ) );

            str.append( ':' );

            str.append( decByte( minutes / 10 ) );
            str.append( decByte( minutes % 10 ) );

            str.append( ':' );

            str.append( decByte( seconds / 10 ) );
            str.append( decByte( seconds % 10 ) );

            if ( nanos != 0 ) {
                str.append( '.' );

                int pow = 100000000; // nanos <= 999999999
                for ( int i = 0; i < 8; i++ ) {
                    final int b = nanos / pow;
                    if ( b == 0 ) break; // done (no trailing zeros)
                    str.append( decByte( b % 10 ) );
                    pow = pow / 10;
                }
            }
        }

        return str;
    }

    @SuppressWarnings("deprecation")
    public static IRubyObject newTime(final ThreadContext context, final Time time) {
        //if ( time == null ) return context.nil;
        final int hours = time.getHours();
        final int minutes = time.getMinutes();
        final int seconds = time.getSeconds();
        //final int offset = time.getTimezoneOffset();

        DateTime dateTime = new DateTime(2000, 1, 1, hours, minutes, seconds, DateTimeZone.UTC);
        return RubyTime.newTime(context.runtime, dateTime);
    }

    @SuppressWarnings("deprecation")
    public static IRubyObject newTime(final ThreadContext context, final Timestamp timestamp) {
        //if ( time == null ) return context.nil;

        int year = timestamp.getYear() + 1900;
        int month = timestamp.getMonth() + 1;
        int day = timestamp.getDate();
        int hours = timestamp.getHours();
        int minutes = timestamp.getMinutes();
        int seconds = timestamp.getSeconds();
        int nanos = timestamp.getNanos();

        DateTime dateTime = new DateTime(year, month, day, hours, minutes, seconds, nanos / 1000);
        return RubyTime.newTime(context.runtime, dateTime);
    }

    public static Timestamp convertToTimestamp(final RubyFloat value) {
        final Timestamp timestamp = new Timestamp(value.getLongValue() * 1000); // millis

        // for usec we shall not use: ((long) floatValue * 1000000) % 1000
        // if ( usec >= 0 ) timestamp.setNanos( timestamp.getNanos() + usec * 1000 );
        // due doubles inaccurate precision it's better to parse to_s :
        final ByteList strValue = ((RubyString) value.to_s()).getByteList();
        final int dot1 = strValue.lastIndexOf('.') + 1, dot4 = dot1 + 3;
        final int len = strValue.getRealSize() - strValue.getBegin();
        if ( dot1 > 0 && dot4 < len ) { // skip .123 but handle .1234
            final int end = Math.min( len - dot4, 3 );
            CharSequence usecSeq = strValue.subSequence(dot4, end);
            final int usec = Integer.parseInt( usecSeq.toString() );
            if ( usec < 10 ) { // 0.1234 ~> 4
                timestamp.setNanos( timestamp.getNanos() + usec * 100 );
            }
            else if ( usec < 100 ) { // 0.12345 ~> 45
                timestamp.setNanos( timestamp.getNanos() + usec * 10 );
            }
            else { // if ( usec < 1000 ) { // 0.123456 ~> 456
                timestamp.setNanos( timestamp.getNanos() + usec );
            }
        }

        return timestamp;
    }

    public static IRubyObject getTimeInDefaultTimeZone(final ThreadContext context, IRubyObject value) {
        if ( value.respondsTo("to_time") ) {
            value = value.callMethod(context, "to_time");
        }
        final String method = isDefaultTimeZoneUTC(context) ? "getutc" : "getlocal";
        if ( value.respondsTo(method) ) {
            value = value.callMethod(context, method);
        }
        return value;
    }

    public static boolean isDefaultTimeZoneUTC(final ThreadContext context) {
        return "utc".equalsIgnoreCase( getDefaultTimeZone(context) );
    }

    public static String getDefaultTimeZone(final ThreadContext context) {
        final RubyClass base = getBase(context.runtime);
        return base.callMethod(context, "default_timezone").toString(); // :utc
    }

}
