package arjdbc.jdbc.types;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as a string
 */
public class StringType extends AbstractType {

    public StringType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a string column into a Ruby string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final String value = resultSet.getString(index);

        if (value == null) {
            return context.nil;
        }

        return RubyString.newInternalFromJavaExternal(context.runtime, value);
    }
}
