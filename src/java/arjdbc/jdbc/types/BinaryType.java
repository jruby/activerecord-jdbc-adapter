package arjdbc.jdbc.types;

import java.io.IOException;
import java.io.InputStream;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

import static arjdbc.util.StringHelper.*;

/**
 * Handles the case when the column should be treated as binary data (i.e. BLOB, BINARY)
 */
public class BinaryType extends AbstractType {

    private static int streamBufferSize = 1024;

    public BinaryType(String label, int idx) {
        super(label, idx);
    }

    /**
     * Converts a binary column into a Ruby string
     * @param context current thread context
     * @param resultSet the jdbc result set to pull the value from
     * @return RubyNil if NULL or RubyString if there is a value
     * @throws SQLException if it failes to retrieve the value from the result set
     */
    @Override
    public IRubyObject extractRubyValue(final ThreadContext context, final ResultSet resultSet) throws SQLException {
        final InputStream stream = resultSet.getBinaryStream(index);

        if (stream == null) {
            return context.nil;
        }

        // We nest these because the #close call in the finally block can throw an IOException
        try {
            try {
                final int bufferSize = streamBufferSize;
                final ByteList bytes = new ByteList(bufferSize);

                readBytes(bytes, stream, bufferSize);

                return context.runtime.newString(bytes);
            } finally {
                stream.close();
            }
        } catch (IOException e) {
            throw new SQLException(e.getMessage(), e);
        }
    }
}
