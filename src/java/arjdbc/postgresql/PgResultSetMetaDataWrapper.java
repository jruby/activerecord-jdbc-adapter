/*
 * A class to loosen restrictions on the PgResultSetMetaData class,
 * we need to be able to get the field and the method is currently set to "package".
 */
package org.postgresql.jdbc;

import java.sql.SQLException;
import org.postgresql.core.BaseConnection;
import org.postgresql.core.Field;
import org.postgresql.jdbc.PgResultSetMetaData;

public class PgResultSetMetaDataWrapper {

    private final PgResultSetMetaData metaData;

    public PgResultSetMetaDataWrapper(PgResultSetMetaData metaData) {
        this.metaData = metaData;
    }

    public Field getField(int i) throws SQLException {
        return this.metaData.getField(i);
    }
}
