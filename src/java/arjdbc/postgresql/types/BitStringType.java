package arjdbc.postgresql.types;

import arjdbc.jdbc.types.BooleanType;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as a bit string, bit, or boolean value
 */
public class BitStringType extends BooleanType {

    public BitStringType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Determines if this field is multiple bits or a single bit (or t/f),
     * if it is multiple bits they are turned into a string, if there is only one it is assumed to be a boolean value.
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyString of bits or RubyBoolean for a boolean value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final String bits = resultSet.getString(index);

        if (bits == null) {
            return context.nil;
        }

        if (bits.length() > 1) {
            return RubyString.newUnicodeString(context.runtime, bits);
        }

        // We assume it is a boolean value if it doesn't have a length
        return super.extractRubyValue(context, resultSet);
    }
}
