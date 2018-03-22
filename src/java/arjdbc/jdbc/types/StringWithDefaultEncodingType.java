package arjdbc.jdbc.types;

import static arjdbc.util.StringHelper.*;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Provides a more optimized option for creating Ruby strings from columns that should be treated as strings
 */
public class StringWithDefaultEncodingType extends AbstractType {

    public StringWithDefaultEncodingType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a string column into a Ruby string by pulling the raw bytes from the column and
     * turning them into a string using the default encoding
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final byte[] value = resultSet.getBytes(index);

        if (value == null) {
            return context.nil;
        }

        return newDefaultInternalString(context.runtime, value);
    }
}
