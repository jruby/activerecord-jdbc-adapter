package arjdbc.jdbc.types;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as a floating point
 */
public class DoubleType extends AbstractType {

    public DoubleType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a floating point column into a Ruby float
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyFloat if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final double value = resultSet.getDouble(index);

        if (value == 0 && resultSet.wasNull()) {
            return context.nil;
        }

        return context.runtime.newFloat(value);
    }
}
