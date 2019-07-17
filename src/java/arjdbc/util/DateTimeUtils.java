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
import java.util.TimeZone;

import org.joda.time.Chronology;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.joda.time.chrono.ISOChronology;
import org.jruby.Ruby;
import org.jruby.RubyFloat;
import org.jruby.RubyString;
import org.jruby.RubyTime;
import org.jruby.javasupport.Java;
import org.jruby.runtime.Block;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;
import org.jruby.util.TypeConverter;

import static arjdbc.util.StringHelper.decByte;

/**
 * Utilities for handling/converting dates and times.
 * @author kares
 */
public abstract class DateTimeUtils {
    public static RubyTime toTime(final ThreadContext context, final IRubyObject value) {
        if (!(value instanceof RubyTime)) { // unlikely
            return (RubyTime) TypeConverter.convertToTypeWithCheck(value, context.runtime.getTime(), "to_time");
        }
        return (RubyTime) value;
    }

    public static DateTime dateTimeInZone(final DateTime dateTime, final DateTimeZone zone) {
        if (zone == dateTime.getZone()) return dateTime;
        return dateTime.withZone(zone);
    }

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

    private static final byte[] DUMMY_TIME_PREFIX = { '2','0','0','0','-','0','1','-','0','1' };

    @SuppressWarnings("deprecation")
    public static ByteList dummyTimeToString(final Timestamp time) {
        final ByteList str = new ByteList(29); // yyyy-mm-dd hh:mm:ss.fffffffff

        int hours = time.getHours();
        int minutes = time.getMinutes();
        int seconds = time.getSeconds();
        int nanos = time.getNanos();

        str.append( DUMMY_TIME_PREFIX );

        str.append( ' ' );

        formatTime(str, hours, minutes, seconds, nanos);

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
            str.append( ' ' );

            formatTime(str, hours, minutes, seconds, nanos);
        }

        return str;
    }

    private static final int NANO_DIGITS_RAILS_CAN_MANAGE = 6; // 'normally' would have been 8

    private static void formatTime(final ByteList str,
        final int hours, final int minutes, final int seconds, final int nanos) {

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
            // NOTE: Rails (still) terrible at handling full nanos precision: '12:30:00.99990000'
            int pow = 100000000; // nanos <= 999999999
            for ( int i = 0; i < NANO_DIGITS_RAILS_CAN_MANAGE; i++ ) {
                final int b = nanos / pow;
                if ( b == 0 ) break; // done (no trailing zeros)
                str.append( decByte( b % 10 ) );
                pow = pow / 10;
            }
        }
    }

    @SuppressWarnings("deprecation")
    public static RubyTime newDummyTime(final ThreadContext context, final Time time, final DateTimeZone defaultZone) {

        final int hours = time.getHours();
        final int minutes = time.getMinutes();
        final int seconds = time.getSeconds();
        //final int offset = time.getTimezoneOffset();

        DateTime dateTime = new DateTime(2000, 1, 1, hours, minutes, seconds, defaultZone);
        return RubyTime.newTime(context.runtime, dateTime, 0);
    }

    @SuppressWarnings("deprecation")
    public static RubyTime newDummyTime(final ThreadContext context, final Timestamp time, final DateTimeZone defaultZone) {

        final int hours = time.getHours();
        final int minutes = time.getMinutes();
        final int seconds = time.getSeconds();
        int nanos = time.getNanos(); // max 999-999-999
        final int millis = nanos / 1000000;
        nanos = nanos % 1000000;

        DateTime dateTime = new DateTime(2000, 1, 1, hours, minutes, seconds, millis, defaultZone);
        return RubyTime.newTime(context.runtime, dateTime, nanos);
    }

    @SuppressWarnings("deprecation")
    public static RubyTime newTime(final ThreadContext context, final Timestamp timestamp, final DateTimeZone defaultZone) {

        final int year = timestamp.getYear() + 1900;
        final int month = timestamp.getMonth() + 1;
        final int day = timestamp.getDate();
        final int hours = timestamp.getHours();
        final int minutes = timestamp.getMinutes();
        final int seconds = timestamp.getSeconds();
        int nanos = timestamp.getNanos(); // max 999-999-999
        final int millis = nanos / 1000000;
        nanos = nanos % 1000000;

        DateTime dateTime = new DateTime(year, month, day, hours, minutes, seconds, millis, defaultZone);
        return RubyTime.newTime(context.runtime, dateTime, nanos);
    }

    @SuppressWarnings("deprecation")
    public static RubyTime newDateAsTime(final ThreadContext context, final Date date, final DateTimeZone zone) {

        final int year = date.getYear() + 1900;
        final int month = date.getMonth() + 1;
        final int day = date.getDate();

        DateTime dateTime = new DateTime(year, month, day, 0, 0, 0, 0, zone);
        return RubyTime.newTime(context.runtime, dateTime, 0);
    }

    @SuppressWarnings("deprecation")
    public static IRubyObject newDate(final ThreadContext context, final Date date, final DateTimeZone zone) {

        final int year = date.getYear() + 1900;
        final int month = date.getMonth() + 1;
        final int day = date.getDate();

        return newDate(context, year, month, day, ISOChronology.getInstance(zone));
    }

    // @Deprecated
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

    public static double adjustTimeFromDefaultZone(final IRubyObject value) {
        // Time's to_f is : ( millis * 1000 + usec ) / 1_000_000.0
        final double time = value.convertToFloat().getDoubleValue(); // to_f
        // NOTE: MySQL assumes default TZ thus need to adjust to match :
        final int offset = TimeZone.getDefault().getOffset((long) time * 1000);
        // Time's to_f is : ( millis * 1000 + usec ) / 1_000_000.0
        return time - ( offset / 1000.0 );
    }

    public static IRubyObject parseDate(final ThreadContext context, final CharSequence str, final DateTimeZone defaultZone)
        throws IllegalArgumentException {
        final int len = str.length();

        int year; int month; int day;

        int start = nonSpaceIndex(str, 0, len); // Skip leading whitespace
        int end = nonDigitIndex(str, start, len);

        if ( end >= len ) {
            throw new IllegalArgumentException("unexpected date value: '" + str + "'");
        }

        // year
        year = extractIntValue(str, start, end);
        start = end + 1; // Skip '-'

        // month
        end = nonDigitIndex(str, start, len);
        month = extractIntValue(str, start, end);

        //sep = str.charAt(end);
        //if ( sep != '-' ) {
        //    throw new NumberFormatException("expected date to be dash-separated, got '" + sep + "'");
        //}

        start = end + 1; // Skip '-'

        // day of month
        end = nonDigitIndex(str, start, len);
        day = extractIntValue(str, start, end);

        return newDate(context, year, month, day, ISOChronology.getInstance(defaultZone));
    }

    public static IRubyObject parseTime(final ThreadContext context, final CharSequence str, final DateTimeZone defaultZone)
        throws IllegalArgumentException {
        final int len = str.length();

        int hour; int minute; int second;
        int millis = 0; long nanos = 0;

        int start = nonSpaceIndex(str, 0, len); // Skip leading whitespace
        int end = nonDigitIndex(str, start, len);

        if ( end >= len ) {
            throw new IllegalArgumentException("unexpected date value: '" + str + "'");
        }

        // hours
        hour = extractIntValue(str, start, end);
        start = end + 1; // Skip ':'

        end = nonDigitIndex(str, start, len);
        // minutes
        minute = extractIntValue(str, start, end);
        start = end + 1; // Skip ':'

        end = nonDigitIndex(str, start, len);
        // seconds
        second = extractIntValue(str, start, end);
        start = end;

        // Fractional seconds.
        if ( start < len && str.charAt(start) == '.' ) {
            end = nonDigitIndex(str, start + 1, len); // Skip '.'
            int numlen = end - (start + 1);
            if (numlen <= 3) {
                millis = extractIntValue(str, start + 1, end);
                for ( ; numlen < 3; ++numlen ) millis *= 10;
            }
            else {
                nanos = extractIntValue(str, start + 1, end);
                for ( ; numlen < 9; ++numlen ) nanos *= 10;
            }
            //start = end;
        }

        DateTime dateTime = new DateTime(2000, 1, 1, hour, minute, second, millis, defaultZone);
        return RubyTime.newTime(context.runtime, dateTime, nanos);
    }

    public static RubyTime parseDateTime(final ThreadContext context, final CharSequence str, final DateTimeZone defaultZone)
        throws IllegalArgumentException {

        boolean hasDate = false;
        int year = 2000; int month = 1; int day = 1;
        boolean hasTime = false;
        int minute = 0; int hour = 0; int second = 0;
        int millis = 0; long nanos = 0;

        DateTimeZone zone = defaultZone; boolean bcEra = false;

        // We try to parse these fields in order; all are optional
        // (but some combinations don't make sense, e.g. if you have
        //  both date and time then they must be whitespace-separated).
        // At least one of date and time must be present.

        //   leading whitespace
        //   yyyy-mm-dd
        //   whitespace
        //   hh:mm:ss
        //   whitespace
        //   timezone in one of the formats:  +hh, -hh, +hh:mm, -hh:mm
        //   whitespace
        //   if date is present, an era specifier: AD or BC
        //   trailing whitespace

        final int len = str.length();

        int start = nonSpaceIndex(str, 0, len); // Skip leading whitespace
        int end = nonDigitIndex(str, start, len);

        // Possibly read date.
        if ( end < len && str.charAt(end) == '-' ) {
            hasDate = true;

            // year
            year = extractIntValue(str, start, end);
            start = end + 1; // Skip '-'

            // month
            end = nonDigitIndex(str, start, len);
            month = extractIntValue(str, start, end);

            char sep = str.charAt(end);
            if ( sep != '-' ) {
                throw new IllegalArgumentException("expected date to be dash-separated, got '" + sep + "'");
            }

            start = end + 1; // Skip '-'

            // day of month
            end = nonDigitIndex(str, start, len);
            day = extractIntValue(str, start, end);

            start = nonSpaceIndex(str, end, len); // Skip trailing whitespace
        }

        // Possibly read time.
        if ( start < len && Character.isDigit( str.charAt(start) ) ) {
            hasTime = true;

            // hours
            end = nonDigitIndex(str, start, len);
            hour = extractIntValue(str, start, end);

            //sep = str.charAt(end);
            //if ( sep != ':' ) {
            //    throw new IllegalArgumentException("expected time to be colon-separated, got '" + sep + "'");
            //}

            start = end + 1; // Skip ':'

            // minutes
            end = nonDigitIndex(str, start, len);
            minute = extractIntValue(str, start, end);

            //sep = str.charAt(end);
            //if ( sep != ':' ) {
            //    throw new IllegalArgumentException("expected time to be colon-separated, got '" + sep + "'");
            //}

            start = end + 1; // Skip ':'

            // seconds
            end = nonDigitIndex(str, start, len);
            second = extractIntValue(str, start, end);
            start = end;

            // Fractional seconds.
            if ( start < len && str.charAt(start) == '.' ) {
                end = nonDigitIndex(str, start + 1, len); // Skip '.'
                int numlen = end - (start + 1);
                if (numlen <= 3) {
                    millis = extractIntValue(str, start + 1, end);
                    for ( ; numlen < 3; ++numlen ) millis *= 10;
                }
                else {
                    // Make sure we always define millis to work around bug in
                    // strftime('%6N') in older version of JRuby (discovered in 9.1.16.0)
                    millis = extractIntValue(str, start + 1, start + 4);
                    nanos = extractIntValue(str, start + 4, end);
                    for ( ; numlen < 9; ++numlen ) nanos *= 10;
                }

                start = end;
            }

            start = nonSpaceIndex(str, start, len); // Skip trailing whitespace
        }

        // Possibly read timezone.
        char sep = start < len ? str.charAt(start) : '\0';
        if ( sep == '+' || sep == '-' ) {
            int zoneSign = (sep == '-') ? -1 : 1;
            int hoursOffset, minutesOffset, secondsOffset;

            end = nonDigitIndex(str, start + 1, len);    // Skip +/-
            hoursOffset = extractIntValue(str, start + 1, end);
            start = end;

            if ( start < len && str.charAt(start) == ':' ) {
                end = nonDigitIndex(str, start + 1, len);  // Skip ':'
                minutesOffset = extractIntValue(str, start + 1, end);
                start = end;
            } else {
                minutesOffset = 0;
            }

            secondsOffset = 0;
            if ( start < len && str.charAt(start) == ':' ) {
                end = nonDigitIndex(str, start + 1, len);  // Skip ':'
                secondsOffset = extractIntValue(str, start + 1, end);
                start = end;
            }

            // Setting offset does not seem to work correctly in all
            // cases.. So get a fresh calendar for a synthetic timezone
            // instead

            int offset = zoneSign * hoursOffset * 60;
            if (offset < 0) {
                offset = offset - Math.abs(minutesOffset);
            } else {
                offset = offset + minutesOffset;
            }
            offset = (offset * 60 + secondsOffset) * 1000;
            zone = DateTimeZone.forOffsetMillis(offset);

            start = nonSpaceIndex(str, start, len); // Skip trailing whitespace
        }

        if ( hasDate && start < len ) {
            final char e1 = str.charAt(start);
            if ( e1 == 'A' && str.charAt(start + 1) == 'D' ) {
                bcEra = false; start += 2;
            }
            else if ( e1 == 'B' && str.charAt(start + 1) == 'C' ) {
                bcEra = true; start += 2;
            }
        }

        if ( start < len ) {
            throw new IllegalArgumentException("trailing junk: '" + str.subSequence(start, len - start) + "' on '" + str + "'");
        }
        if ( ! hasTime && ! hasDate ) {
            throw new IllegalArgumentException("'"+ str +"' has neither date nor time");
        }

        if ( bcEra ) year = -1 * year + 1; // since JODA is treating year 0 as non-existent

        DateTime dateTime = new DateTime(year, month, day, hour, minute, second, millis, zone);
        return RubyTime.newTime(context.runtime, dateTime, nanos);
    }

    private static IRubyObject newDate(final ThreadContext context, final int year, final int month, final int day,
                                       final ISOChronology chronology) {
        // NOTE: JRuby really needs a native date.rb until than its a bit costly going from ...
        // java.sql.Date -> allocating a DateTime proxy, help a bit by shooting at the internals
        //
        //  def initialize(dt_or_ajd=0, of=0, sg=ITALY, sub_millis=0)
        //    if JODA::DateTime === dt_or_ajd
        //      @dt = dt_or_ajd

        DateTime dateTime = new DateTime(year, month, day, 0, 0, 0, 0, chronology);

        final Ruby runtime = context.runtime;
        return runtime.getClass("Date").newInstance(context, Java.getInstance(runtime, dateTime), Block.NULL_BLOCK);
    }

    @SuppressWarnings("deprecation")
    private static int nonSpaceIndex(final CharSequence str, int beg, int len) {
        for ( int i = beg; i < len; i++ ) {
            if ( ! Character.isSpace( str.charAt(i) ) ) return i;
        }
        return len;
    }

    private static int nonDigitIndex(final CharSequence str, int beg, int len) {
        for ( int i = beg; i < len; i++ ) {
            if ( ! Character.isDigit( str.charAt(i) ) ) return i;
        }
        return len;
    }

    private static int extractIntValue(final CharSequence str, int beg, int end) {
        int n = 0;
        for ( int i = beg; i < end; i++ ) {
            n = 10 * n + ( str.charAt(i) - '0' );
        }
        return n;
    }


    private static final char[] ZEROS = {'0', '0', '0', '0', '0', '0'};
    private static final char[][] NUMBERS;

    static {
        // maximum value is 60 (seconds)
        NUMBERS = new char[60][];
        for (int i = 0; i < NUMBERS.length; i++) {
            NUMBERS[i] = ((i < 10 ? "0" : "") + Integer.toString(i)).toCharArray();
        }
    }

    /**
     * Converts a ruby timestamp to a java string, optionally with timezone and timezone adjustment
     * @param context
     * @param value the ruby value, typically a Time
     * @param zone DateTimeZone to adjust to, optional
     * @param withZone include timezone in the string?
     * @return timestamp as string
     */
    public static String timestampTimeToString(final ThreadContext context,
                                               final IRubyObject value, DateTimeZone zone, boolean withZone) {
        RubyTime timeValue = toTime(context, value);
        DateTime dt = timeValue.getDateTime();

        StringBuilder sb = new StringBuilder(36);

        int year = dt.getYear();
        if (year <= 0) {
            year--;
        } else if (zone != null) {
            dt = dateTimeInZone(dt, zone);
            year = dt.getYear();
        }

        Chronology chrono = dt.getChronology();
        long millis = dt.getMillis();

        // always use 4 digits for year to avoid short dates being misinterpreted
        sb.append(Math.abs(year));
        int lead = 4 - sb.length();
        if (lead > 0) sb.insert(0, ZEROS, 0, lead);
        sb.append('-');
        sb.append(NUMBERS[chrono.monthOfYear().get(millis)]);
        sb.append('-');
        sb.append(NUMBERS[chrono.dayOfMonth().get(millis)]);
        if (year < 0) sb.append(" BC");
        sb.append(' ');

        appendTime(sb, chrono, millis, (int) timeValue.getUSec(), withZone);

        return sb.toString();
    }

    /**
     * Converts a ruby time to a java string, optionally with timezone and timezone adjustment
     * @param context
     * @param value the ruby value, typically a Time
     * @param zone DateTimeZone to adjust to, optional
     * @param withZone include timezone in the string?
     * @return time as string
     */
    public static String timeString(final ThreadContext context,
                                    final IRubyObject value, DateTimeZone zone, boolean withZone) {
        StringBuilder sb = new StringBuilder(21);
        RubyTime timeValue = toTime(context, value);
        DateTime dt = timeValue.getDateTime();
        if (zone != null) dt = dateTimeInZone(dt, zone);

        appendTime(sb, dt.getChronology(), dt.getMillis(), (int) timeValue.getUSec(), withZone);
        return sb.toString();
    }

    private static void appendTime(StringBuilder sb, Chronology chrono,
                                   long millis, int usec, boolean withZone) {
        sb.append(NUMBERS[chrono.hourOfDay().get(millis)]);
        sb.append(':');
        sb.append(NUMBERS[chrono.minuteOfHour().get(millis)]);
        sb.append(':');
        sb.append(NUMBERS[chrono.secondOfMinute().get(millis)]);

        // PG has microsecond resolution. Change when nanos are required
        int micros = chrono.millisOfSecond().get(millis) * 1000 + usec;
        if (micros > 0) {
            sb.append('.');

            int len = sb.length();
            sb.append(micros);
            int lead = 6 - (sb.length() - len);
            if (lead > 0) sb.insert(len, ZEROS, 0, lead);

            for (int end = sb.length() - 1; sb.charAt(end) == '0'; end--) {
                sb.setLength(end);
            }
        }

        if (withZone) {
            int offset = chrono.getZone().getOffset(millis) / 1000;
            int absoff = Math.abs(offset);
            int hours = absoff / 3600;
            int mins = (absoff - hours * 3600) / 60;

            sb.append(offset < 0 ? '-' : '+');
            sb.append(NUMBERS[hours]).append(':').append(NUMBERS[mins]);
        }
    }
}
