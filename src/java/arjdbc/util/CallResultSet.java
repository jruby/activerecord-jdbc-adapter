/*
 * The MIT License
 *
 * Copyright 2014 Karol Bucek.
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
package arjdbc.util;

import java.io.InputStream;
import java.io.Reader;
import java.math.BigDecimal;
import java.net.URL;
import java.sql.Array;
import java.sql.Blob;
import java.sql.CallableStatement;
import java.sql.Clob;
import java.sql.Date;
import java.sql.NClob;
import java.sql.Ref;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.RowId;
import java.sql.SQLException;
import java.sql.SQLFeatureNotSupportedException;
import java.sql.SQLWarning;
import java.sql.SQLXML;
import java.sql.Time;
import java.sql.Timestamp;
import java.util.Calendar;
import java.util.Map;

/**
 * {@link ResultSet} "emulation" for {@link CallableStatement}.
 *
 * @author kares
 */
public class CallResultSet implements ResultSet {

    private final CallableStatement call;
    private final int size; private int row;

    public CallResultSet(CallableStatement call) {
        this(call, 1);
    }

    public CallResultSet(CallableStatement call, final int size) {
        this.call = call; this.size = size;
    }

    public CallableStatement getStatement() {
        return call;
    }

    @SuppressWarnings("unchecked")
    public <T> T unwrap(Class<T> iface) throws SQLException {
        if ( iface.isAssignableFrom(getClass()) ) return (T) this;
        return call.unwrap(iface);
    }

    public boolean isWrapperFor(Class<?> iface) throws SQLException {
        if ( iface.isAssignableFrom(getClass()) ) return true;
        return call.isWrapperFor(iface);
    }

    public int getHoldability() {
        return 0;
        // HOLD_CURSORS_OVER_COMMIT = 1
        // CLOSE_CURSORS_AT_COMMIT = 2
    }

    public boolean isClosed() throws SQLException {
        return call.isClosed();
    }

    public void close() throws SQLException {
        // NOOP
    }

    public int getRow() { return row; }

    public boolean absolute(int row) {
        if ( row < 0 ) row = 0;
        this.row = row; return row <= size && row > 0;
    }
    public boolean relative(int rows) {
        return absolute(this.row + rows);
    }

    //public boolean next() {
    //    return ( ++row <= size );
    //}

    public boolean next() { return relative(+1); }
    public boolean previous() { return relative(-1); }

    public boolean first() { return absolute(1); }
    public boolean last() { return absolute(-1); }

    public boolean isBeforeFirst() { return row <= 0; }
    public boolean isAfterLast() { return row > size; }

    public boolean isFirst() { return row == 1; }
    public boolean isLast() { return row == size; }

    public void beforeFirst() { row = 0; }
    public void afterLast() { row = size + 1; }

    public ResultSetMetaData getMetaData() throws SQLException {
        return call.getMetaData(); // NOTE: should be fine - right?
    }

    public int findColumn(String columnLabel) throws SQLException {
        getObject(columnLabel); return 1;
    }

    public void setFetchDirection(int direction) throws SQLException {
        call.setFetchDirection(direction);
    }

    public int getFetchDirection() throws SQLException {
        return call.getFetchDirection();
    }

    public void setFetchSize(int rows) throws SQLException {
        // NOOP
    }

    public int getFetchSize() throws SQLException {
        return 1;
    }

    public int getType() throws SQLException {
        return TYPE_SCROLL_INSENSITIVE;
    }

    public int getConcurrency() throws SQLException {
        return CONCUR_READ_ONLY;
    }


    public boolean wasNull() throws SQLException {
        return call.wasNull();
    }

    // GET-ERS :

    public String getString(int columnIndex) throws SQLException {
        return call.getString(columnIndex);
    }

    public boolean getBoolean(int columnIndex) throws SQLException {
        return call.getBoolean(columnIndex);
    }

    public byte getByte(int columnIndex) throws SQLException {
        return call.getByte(columnIndex);
    }

    public short getShort(int columnIndex) throws SQLException {
        return call.getShort(columnIndex);
    }

    public int getInt(int columnIndex) throws SQLException {
        return call.getInt(columnIndex);
    }

    public long getLong(int columnIndex) throws SQLException {
        return call.getLong(columnIndex);
    }

    public float getFloat(int columnIndex) throws SQLException {
        return call.getFloat(columnIndex);
    }

    public double getDouble(int columnIndex) throws SQLException {
        return call.getDouble(columnIndex);
    }

    @SuppressWarnings("deprecation")
    public BigDecimal getBigDecimal(int columnIndex, int scale) throws SQLException {
        return call.getBigDecimal(columnIndex, scale);
    }

    public byte[] getBytes(int columnIndex) throws SQLException {
        return call.getBytes(columnIndex);
    }

    public Date getDate(int columnIndex) throws SQLException {
        return call.getDate(columnIndex);
    }

    public Time getTime(int columnIndex) throws SQLException {
        return call.getTime(columnIndex);
    }

    public Timestamp getTimestamp(int columnIndex) throws SQLException {
        return call.getTimestamp(columnIndex);
    }

    public InputStream getAsciiStream(int columnIndex) throws SQLException {
        throw new UnsupportedOperationException("getAsciiStream()");
    }

    @SuppressWarnings("deprecation")
    public InputStream getUnicodeStream(int columnIndex) throws SQLException {
        throw new UnsupportedOperationException("getUnicodeStream()");
    }

    public InputStream getBinaryStream(int columnIndex) throws SQLException {
        throw new UnsupportedOperationException("getBinaryStream()");
    }

    public String getString(String columnLabel) throws SQLException {
        return call.getString(columnLabel);
    }

    public boolean getBoolean(String columnLabel) throws SQLException {
        return call.getBoolean(columnLabel);
    }

    public byte getByte(String columnLabel) throws SQLException {
        return call.getByte(columnLabel);
    }

    public short getShort(String columnLabel) throws SQLException {
        return call.getShort(columnLabel);
    }

    public int getInt(String columnLabel) throws SQLException {
        return call.getInt(columnLabel);
    }

    public long getLong(String columnLabel) throws SQLException {
        return call.getLong(columnLabel);
    }

    public float getFloat(String columnLabel) throws SQLException {
        return call.getFloat(columnLabel);
    }

    public double getDouble(String columnLabel) throws SQLException {
        return call.getDouble(columnLabel);
    }

    @SuppressWarnings("deprecation")
    public BigDecimal getBigDecimal(String columnLabel, int scale) throws SQLException {
        return call.getBigDecimal(columnLabel);
    }

    public byte[] getBytes(String columnLabel) throws SQLException {
        return call.getBytes(columnLabel);
    }

    public Date getDate(String columnLabel) throws SQLException {
        return call.getDate(columnLabel);
    }

    public Time getTime(String columnLabel) throws SQLException {
        return call.getTime(columnLabel);
    }

    public Timestamp getTimestamp(String columnLabel) throws SQLException {
        return call.getTimestamp(columnLabel);
    }

    public InputStream getAsciiStream(String columnLabel) throws SQLException {
        throw new UnsupportedOperationException("getAsciiStream()");
    }

    @SuppressWarnings("deprecation")
    public InputStream getUnicodeStream(String columnLabel) throws SQLException {
        throw new UnsupportedOperationException("getUnicodeStream()");
    }

    public InputStream getBinaryStream(String columnLabel) throws SQLException {
        throw new UnsupportedOperationException("getBinaryStream()");
    }

    public Object getObject(int columnIndex) throws SQLException {
        return call.getObject(columnIndex);
    }

    public Object getObject(String columnLabel) throws SQLException {
        return call.getObject(columnLabel);
    }

    public Reader getCharacterStream(int columnIndex) throws SQLException {
        return call.getCharacterStream(columnIndex);
    }

    public Reader getCharacterStream(String columnLabel) throws SQLException {
        return call.getCharacterStream(columnLabel);
    }

    public BigDecimal getBigDecimal(int columnIndex) throws SQLException {
        return call.getBigDecimal(columnIndex);
    }

    public BigDecimal getBigDecimal(String columnLabel) throws SQLException {
        return call.getBigDecimal(columnLabel);
    }

    public Object getObject(int columnIndex, Map<String, Class<?>> map) throws SQLException {
        return call.getObject(columnIndex, map);
    }

    public Ref getRef(int columnIndex) throws SQLException {
        return call.getRef(columnIndex);
    }

    public Blob getBlob(int columnIndex) throws SQLException {
        return call.getBlob(columnIndex);
    }

    public Clob getClob(int columnIndex) throws SQLException {
        return call.getClob(columnIndex);
    }

    public Array getArray(int columnIndex) throws SQLException {
        return call.getArray(columnIndex);
    }

    public Object getObject(String columnLabel, Map<String, Class<?>> map) throws SQLException {
        return call.getObject(columnLabel, map);
    }

    public Ref getRef(String columnLabel) throws SQLException {
        return call.getRef(columnLabel);
    }

    public Blob getBlob(String columnLabel) throws SQLException {
        return call.getBlob(columnLabel);
    }

    public Clob getClob(String columnLabel) throws SQLException {
        return call.getClob(columnLabel);
    }

    public Array getArray(String columnLabel) throws SQLException {
        return call.getArray(columnLabel);
    }

    public Date getDate(int columnIndex, Calendar cal) throws SQLException {
        return call.getDate(columnIndex, cal);
    }

    public Date getDate(String columnLabel, Calendar cal) throws SQLException {
        return call.getDate(columnLabel, cal);
    }

    public Time getTime(int columnIndex, Calendar cal) throws SQLException {
        return call.getTime(columnIndex, cal);
    }

    public Time getTime(String columnLabel, Calendar cal) throws SQLException {
        return call.getTime(columnLabel, cal);
    }

    public Timestamp getTimestamp(int columnIndex, Calendar cal) throws SQLException {
        return call.getTimestamp(columnIndex, cal);
    }

    public Timestamp getTimestamp(String columnLabel, Calendar cal) throws SQLException {
        return call.getTimestamp(columnLabel, cal);
    }

    public URL getURL(int columnIndex) throws SQLException {
        return call.getURL(columnIndex);
    }

    public URL getURL(String columnLabel) throws SQLException {
        return call.getURL(columnLabel);
    }

    public RowId getRowId(int columnIndex) throws SQLException {
        return call.getRowId(columnIndex);
    }

    public RowId getRowId(String columnLabel) throws SQLException {
        return call.getRowId(columnLabel);
    }

    public NClob getNClob(int columnIndex) throws SQLException {
        return call.getNClob(columnIndex);
    }

    public NClob getNClob(String columnLabel) throws SQLException {
        return call.getNClob(columnLabel);
    }

    public SQLXML getSQLXML(int columnIndex) throws SQLException {
        return call.getSQLXML(columnIndex);
    }

    public SQLXML getSQLXML(String columnLabel) throws SQLException {
        return call.getSQLXML(columnLabel);
    }

    public String getNString(int columnIndex) throws SQLException {
        return call.getNString(columnIndex);
    }

    public String getNString(String columnLabel) throws SQLException {
        return call.getNString(columnLabel);
    }

    public Reader getNCharacterStream(int columnIndex) throws SQLException {
        return call.getNCharacterStream(columnIndex);
    }

    public Reader getNCharacterStream(String columnLabel) throws SQLException {
        return call.getNCharacterStream(columnLabel);
    }

    public <T> T getObject(int columnIndex, Class<T> type) throws SQLException {
        return call.getObject(columnIndex, type);
    }

    public <T> T getObject(String columnLabel, Class<T> type) throws SQLException {
        return call.getObject(columnLabel, type);
    }


    // NOT SUPPORTED OPERATIONS :


    public SQLWarning getWarnings() throws SQLException {
        return null; // NOOP
    }

    public void clearWarnings() throws SQLException {
        // NOOP
    }

    public String getCursorName() throws SQLException {
        return null; // NOOP
    }


    public boolean rowUpdated() throws SQLException {
        throw new SQLFeatureNotSupportedException("row updates");
    }

    public boolean rowInserted() throws SQLException {
        throw new SQLFeatureNotSupportedException("row inserts");
    }

    public boolean rowDeleted() throws SQLException {
        throw new SQLFeatureNotSupportedException("row deletes");
    }

    public void insertRow() throws SQLException {
        throw new SQLFeatureNotSupportedException("row inserts");
    }

    public void updateRow() throws SQLException {
        throw new SQLFeatureNotSupportedException("row updates");
    }

    public void deleteRow() throws SQLException {
        throw new SQLFeatureNotSupportedException("row deletes");
    }

    public void refreshRow() throws SQLException {
        // NOOOP
    }

    public void cancelRowUpdates() throws SQLException {
        // NOOP
    }

    public void moveToInsertRow() throws SQLException {
        throw new SQLFeatureNotSupportedException();
    }

    public void moveToCurrentRow() throws SQLException {
        throw new SQLFeatureNotSupportedException();
    }


    public void updateNull(int columnIndex) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBoolean(int columnIndex, boolean x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateByte(int columnIndex, byte x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateShort(int columnIndex, short x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateInt(int columnIndex, int x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateLong(int columnIndex, long x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateFloat(int columnIndex, float x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateDouble(int columnIndex, double x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBigDecimal(int columnIndex, BigDecimal x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateString(int columnIndex, String x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBytes(int columnIndex, byte[] x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateDate(int columnIndex, Date x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateTime(int columnIndex, Time x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateTimestamp(int columnIndex, Timestamp x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateAsciiStream(int columnIndex, InputStream x, int length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBinaryStream(int columnIndex, InputStream x, int length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateCharacterStream(int columnIndex, Reader x, int length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateObject(int columnIndex, Object x, int scaleOrLength) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateObject(int columnIndex, Object x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNull(String columnLabel) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBoolean(String columnLabel, boolean x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateByte(String columnLabel, byte x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateShort(String columnLabel, short x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateInt(String columnLabel, int x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateLong(String columnLabel, long x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateFloat(String columnLabel, float x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateDouble(String columnLabel, double x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBigDecimal(String columnLabel, BigDecimal x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateString(String columnLabel, String x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBytes(String columnLabel, byte[] x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateDate(String columnLabel, Date x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateTime(String columnLabel, Time x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateTimestamp(String columnLabel, Timestamp x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateAsciiStream(String columnLabel, InputStream x, int length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBinaryStream(String columnLabel, InputStream x, int length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateCharacterStream(String columnLabel, Reader reader, int length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateObject(String columnLabel, Object x, int scaleOrLength) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateObject(String columnLabel, Object x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateRef(int columnIndex, Ref x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateRef(String columnLabel, Ref x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBlob(int columnIndex, Blob x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBlob(String columnLabel, Blob x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateClob(int columnIndex, Clob x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateClob(String columnLabel, Clob x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateArray(int columnIndex, Array x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateArray(String columnLabel, Array x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateRowId(int columnIndex, RowId x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateRowId(String columnLabel, RowId x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNString(int columnIndex, String nString) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNString(String columnLabel, String nString) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNClob(int columnIndex, NClob nClob) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNClob(String columnLabel, NClob nClob) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateSQLXML(int columnIndex, SQLXML xmlObject) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateSQLXML(String columnLabel, SQLXML xmlObject) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNCharacterStream(int columnIndex, Reader x, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNCharacterStream(String columnLabel, Reader reader, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateAsciiStream(int columnIndex, InputStream x, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBinaryStream(int columnIndex, InputStream x, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateCharacterStream(int columnIndex, Reader x, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateAsciiStream(String columnLabel, InputStream x, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBinaryStream(String columnLabel, InputStream x, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateCharacterStream(String columnLabel, Reader reader, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBlob(int columnIndex, InputStream inputStream, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBlob(String columnLabel, InputStream inputStream, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateClob(int columnIndex, Reader reader, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateClob(String columnLabel, Reader reader, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNClob(int columnIndex, Reader reader, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNClob(String columnLabel, Reader reader, long length) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNCharacterStream(int columnIndex, Reader x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNCharacterStream(String columnLabel, Reader reader) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateAsciiStream(int columnIndex, InputStream x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBinaryStream(int columnIndex, InputStream x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateCharacterStream(int columnIndex, Reader x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateAsciiStream(String columnLabel, InputStream x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBinaryStream(String columnLabel, InputStream x) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateCharacterStream(String columnLabel, Reader reader) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBlob(int columnIndex, InputStream inputStream) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateBlob(String columnLabel, InputStream inputStream) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateClob(int columnIndex, Reader reader) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateClob(String columnLabel, Reader reader) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNClob(int columnIndex, Reader reader) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

    public void updateNClob(String columnLabel, Reader reader) throws SQLException {
        throw new SQLFeatureNotSupportedException("updates");
    }

}