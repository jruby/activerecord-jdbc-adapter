package arjdbc.jdbc.types;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.SQLXML;

import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as an XML string
 */
public class XMLType extends AbstractType {

    public XMLType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts an XML column into a Ruby string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final SQLXML value = resultSet.getSQLXML(index);

        if (value == null) {
            return context.nil;
        }

        try {
            return RubyString.newInternalFromJavaExternal(context.runtime, value.getString());
        } finally {
            value.free();
        }
    }
}
