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
import java.sql.ResultSet;
import java.sql.SQLException;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Driver specifics hidden behind curtains.
 * 
 * @author kares
 */
interface DriverImplementation {

    Connection newConnection(final Connection connection) throws SQLException ;

    //

    IRubyObject objectToRuby(final ThreadContext context,
        final ResultSet resultSet, final int column) throws SQLException ;

    // prepared statements :

    boolean setStringParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject column, final int type) throws SQLException ;

    boolean setTimestampParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject column, final int type) throws SQLException ;

    boolean setObjectParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, Object value,
        final IRubyObject column, final int type) throws SQLException ;

    /*
    public void setJsonParameter(final ThreadContext context,
            final PreparedStatement statement, final int index,
            Object value, final IRubyObject column) throws SQLException ;

    public void setRangeParameter(final ThreadContext context,
        final PreparedStatement statement, final int index,
        final Object value, final IRubyObject column,
        final String columnType) throws SQLException ;

    public void setTsVectorParameter(
        final PreparedStatement statement, final int index,
        Object value) throws SQLException ; */

}
