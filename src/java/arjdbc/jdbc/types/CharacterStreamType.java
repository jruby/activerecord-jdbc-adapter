package arjdbc.jdbc.types;

import java.io.IOException;
import java.io.Reader;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Handles the case when the column should be treated as a character stream (i.e. CLOB, LONGVARCHAR)
 */
public class CharacterStreamType extends AbstractType {

    private static int streamBufferSize = 1024;

    public CharacterStreamType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a character stream column into a Ruby string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final Reader reader = resultSet.getCharacterStream(index);

        if (reader == null) {
            return context.nil;
        }

        // We nest these because the #close call can throw an IOException
        try {
            try {
                final int bufferSize = streamBufferSize;
                final StringBuilder string = new StringBuilder(bufferSize);

                final char[] buffer = new char[bufferSize];

                int len = reader.read(buffer);
                while (len != -1) {
                    string.append(buffer, 0, len);
                    len = reader.read(buffer);
                }

                return RubyString.newInternalFromJavaExternal(context.runtime, string.toString());
            } finally {
                reader.close();
            }
        } catch (IOException e) {
            throw new SQLException(e.getMessage(), e);
        }
    }
}
