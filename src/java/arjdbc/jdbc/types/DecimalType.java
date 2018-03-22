package arjdbc.jdbc.types;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.ext.bigdecimal.RubyBigDecimal;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as a decimal value
 */
public class DecimalType extends AbstractType {

    public DecimalType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a decimal column into a Ruby big decimal
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyBigDecimal if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final BigDecimal value = resultSet.getBigDecimal(index);

        if (value == null) {
            return context.nil;
        }

        return new RubyBigDecimal(context.runtime, value);
    }
}
