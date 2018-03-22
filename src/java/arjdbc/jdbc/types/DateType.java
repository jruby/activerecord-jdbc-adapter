package arjdbc.jdbc.types;

import arjdbc.util.DateTimeUtils;

import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as a date
 */
public class DateType extends AbstractType {

    public DateType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a JDBC date object to a Ruby date
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyDate if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {

        final Date value = resultSet.getDate(index);

        // This previously returned an empty string here if 'wasNull()' was false
        // so if we see odd behavior that may need to be added back
        if (value == null) {
            return context.nil;
        }

        return DateTimeUtils.newDateAsTime(context, value, null).callMethod(context, "to_date");
    }
}
