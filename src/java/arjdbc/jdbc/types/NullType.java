package arjdbc.jdbc.types;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be assumed to always be NULL
 */
public class NullType extends AbstractType {

    public NullType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Assumes this column is always NULL
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        return context.nil;
    }
}
