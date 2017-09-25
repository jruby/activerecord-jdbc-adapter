/*
 * The MIT License
 *
 * Copyright 2015 Karol Bucek.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package arjdbc.postgresql;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

import org.postgresql.core.BaseConnection;
//import org.postgresql.jdbc4.Jdbc4Array;

/**
 * Official JDBC driver internals (for < 9.4.1207).
 *
 * @author kares
 */
class PGOldDriverImplementation extends PGDriverImplementation {

    @Override
    void setArrayImpl(final Connection connection, final int oid,
        final PreparedStatement statement, final int index, final String valueStr) throws SQLException {
        // TODO set-up "dual postgres driver" compilation to avoid reflection
        // statement.setArray(index, new Jdbc4Array(connection.unwrap(BaseConnection.class), oid, valueStr));

        final java.sql.Array valueArr;
        try {
            valueArr = Jdbc4Array.newInstance(connection.unwrap(BaseConnection.class), oid, valueStr);
        }
        catch (InstantiationException ex) { throw new AssertionError(ex); }
        catch (IllegalAccessException ex) { throw new AssertionError(ex); }
        catch (Exception ex) { throw new AssertionError(ex.getCause() != null ? ex.getCause() : ex); }
        statement.setArray(index, valueArr);
    }

    static final Class<?> JDBC4_ARRAY_CLASS;
    static {
        Class<?> klass;
        try {
            klass = Class.forName("org.postgresql.jdbc4.Jdbc4Array");
        }
        catch (ClassNotFoundException e) {
            klass = null;
        }
        JDBC4_ARRAY_CLASS = klass;

        java.lang.reflect.Constructor constructor;
        if (JDBC4_ARRAY_CLASS != null) {
            try {
                constructor = JDBC4_ARRAY_CLASS.getConstructor(BaseConnection.class, Integer.TYPE, String.class);
            }
            catch (NoSuchMethodException ex) { throw new AssertionError(ex); }
        }
        else {
            constructor = null;
        }
        Jdbc4Array = constructor;
    }

    private static final java.lang.reflect.Constructor<java.sql.Array> Jdbc4Array;

}
