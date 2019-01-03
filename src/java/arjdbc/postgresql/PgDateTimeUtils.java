package arjdbc.postgresql;

import arjdbc.util.DateTimeUtils;
import org.joda.time.DateTimeZone;
import org.jruby.RubyArray;
import org.jruby.RubyFloat;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * PostgreSQL specific DateTime/Timestamp helpers
 * @author dritz
 */
public abstract class PgDateTimeUtils extends DateTimeUtils {
    /**
     * Convert a ruby value to a PostgreSQL timestamp string
     * @param context
     * @param value Ruby value, typically a Time instance
     * @param zone DateTimeZone to adjust to, optional
     * @param withZone include timezone in string?
     * @return A string fit for PostgreSQL
     */
    public static String timestampValueToString(final ThreadContext context, IRubyObject value, DateTimeZone zone,
                                         boolean withZone) {
        if (value instanceof RubyFloat) {
            final double dv = ((RubyFloat) value).getValue();
            if (dv == Double.POSITIVE_INFINITY) {
                return "infinity";
            } else if (dv == Double.NEGATIVE_INFINITY) {
                return "-infinity";
            }
        }
        return timestampTimeToString(context, value, zone, withZone);
    }

    /**
     * Converts a RubyArray with timestamp values to a java array of PostgreSQL timestamp strings
     * @param context
     * @param rubyArray
     * @return Array of timestamp strings
     */
    public static String[] timestampStringArray(final ThreadContext context, final RubyArray rubyArray) {
        int size = rubyArray.size();
        String[] values = new String[size];

        for (int i = 0; i < size; i++) {
            IRubyObject elem = rubyArray.eltInternal(i);
            values[i] = timestampValueToString(context, elem, DateTimeZone.UTC, false);
        }
        return values;
    }
}
