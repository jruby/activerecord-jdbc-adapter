package arjdbc.jdbc.types;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as an integer
 */
public class IntegerType extends AbstractType {

    public IntegerType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts an integer column into a Ruby integer.
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyInteger if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final long value = resultSet.getLong(index);

        if (value == 0 && resultSet.wasNull()) {
            return context.nil;
        }

        return context.runtime.newFixnum(value);
    }
}
