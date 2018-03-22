package arjdbc.jdbc.types;

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the generic case where we don't know the type so we just try to convert
 * it to a Ruby object.
 */
public class ObjectType extends AbstractType {

    public ObjectType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts the column into a RubyObject
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyObject if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final Object value = resultSet.getObject(index);

        if (value == null) {
            return context.nil;
        }

        return JavaUtil.convertJavaToRuby(context.runtime, value);
    }
}
