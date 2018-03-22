package arjdbc.jdbc.types;

import java.math.BigInteger;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.RubyBignum;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column contains integers larger than a regular integer can hold
 */
public class BigIntegerType extends AbstractType {

    public BigIntegerType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a large integer column into a Ruby bignum
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyBignum if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final String value = resultSet.getString(index);

        if (value == null) {
            return context.nil;
        }

        return RubyBignum.bignorm(context.runtime, new BigInteger(value));
    }
}
