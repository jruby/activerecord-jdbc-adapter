package arjdbc.jdbc.types;

import arjdbc.util.StringCache;

import java.io.IOException;
import java.io.InputStream;
import java.lang.String;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;

import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/*
 * Base class to support converting JDBC result sets into Ruby objects
 */
public abstract class AbstractType {

    private static final StringCache STRING_CACHE = new StringCache();

    protected final int index;
    private final String label;
    private RubyString name;

    /**
     * @param label the name of the column
     * @param idx the index of the column in the result set
     */
    protected AbstractType(String label, int idx) {
        this.label = label;
        this.index = idx;
    }

    /*
     * Fetches the data for this column from the current row in the result set
     * and converts it to its Ruby equivalent
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return IRubyObject
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    abstract public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException;

    public String getName() {
        return label;
    }

    /**
     * Gets a Ruby string version of the column name
     * @param context the current thread context
     * @return the RubyString version of the column name
     */
    public RubyString getName(final ThreadContext context) {
        if (name == null) {
            name = STRING_CACHE.get(context, label);
        }
        return name;
    }

}
