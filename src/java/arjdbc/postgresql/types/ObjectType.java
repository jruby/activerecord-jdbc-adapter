package arjdbc.postgresql.types;

import arjdbc.jdbc.types.AbstractType;

import java.lang.StringBuilder;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

import org.jruby.Ruby;
import org.jruby.RubyHash;
import org.jruby.RubyString;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.postgresql.geometric.PGbox;
import org.postgresql.geometric.PGcircle;
import org.postgresql.geometric.PGline;
import org.postgresql.geometric.PGlseg;
import org.postgresql.geometric.PGpath;
import org.postgresql.geometric.PGpoint;
import org.postgresql.geometric.PGpolygon;
import org.postgresql.util.PGInterval;
import org.postgresql.util.PGobject;

/**
 * Handles all the random types that a postgres column can be that classify as "OTHER"
 */
public class ObjectType extends AbstractType {

    // Used to wipe trailing 0's from points (3.0, 5.6) -> (3, 5.6)
    private static final Pattern pointCleanerPattern = Pattern.compile("\\.0\\b");

    public ObjectType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Detects PG specific types and converts them to their Ruby equivalents
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyHash/RubyString/RubyObject
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final Object object = resultSet.getObject(index);

        if (object == null) {
            return context.nil;
        }

        final Ruby runtime = context.runtime;
        final Class<?> objectClass = object.getClass();

        if (objectClass == UUID.class) {
            return runtime.newString(object.toString());
        }

        if (object instanceof PGobject) {

            if (objectClass == PGInterval.class) {
                return runtime.newString(formatInterval(object));
            }

            if (objectClass == PGbox.class || objectClass == PGcircle.class ||
                objectClass == PGline.class || objectClass == PGlseg.class ||
                objectClass == PGpath.class || objectClass == PGpoint.class ||
                objectClass == PGpolygon.class ) {
                // AR 5.0+ expects that points don't have the '.0' if it is an integer
                return runtime.newString(pointCleanerPattern.matcher(object.toString()).replaceAll(""));
            }

            // PG 9.2 JSON type will be returned here as well
            return runtime.newString(object.toString());
        }

        if (object instanceof Map) { // hstore
            // by default we avoid double parsing by driver and then column :
            final RubyHash rubyObject = RubyHash.newHash(context.runtime);
            rubyObject.putAll((Map) object); // converts keys/values to ruby
            return rubyObject;
        }

        return JavaUtil.convertJavaToRuby(runtime, object);
    }

    // NOTE: do not use PG classes in the API so that loading is delayed !
    private String formatInterval(final Object object) {
        final PGInterval interval = (PGInterval) object;
        final StringBuilder str = new StringBuilder(32);

        final int years = interval.getYears();
        if (years != 0) {
            str.append(years).append(" years ");
        }

        final int months = interval.getMonths();
        if (months != 0) {
            str.append(months).append(" months ");
        }

        final int days = interval.getDays();
        if (days != 0) {
            str.append(days).append(" days ");
        }

        final int hours = interval.getHours();
        final int mins = interval.getMinutes();
        final int secs = (int) interval.getSeconds();
        if (hours != 0 || mins != 0 || secs != 0) { // xx:yy:zz if not all 00

            if (hours < 10) {
                str.append('0');
            }

            str.append(hours).append(':');

            if (mins < 10) {
                str.append('0');
            }

            str.append(mins).append(':');

            if (secs < 10) {
                str.append('0');
            }

            str.append(secs);

        } else if (str.length() > 1) {
            str.deleteCharAt(str.length() - 1); // " " at the end
        }

        return str.toString();
    }
}
