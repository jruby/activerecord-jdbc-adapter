package arjdbc.jdbc.types;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as a boolean value
 */
public class BooleanType extends AbstractType {

    public BooleanType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a boolean column into a Ruby boolean
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyBoolean if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final boolean value = resultSet.getBoolean(index);

        if (value == false && resultSet.wasNull()) {
            return context.nil;
        }

        return context.runtime.newBoolean(value);
    }
}
