/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package jdbc_adapter;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

/**
 *
 * @author nicksieger
 */
public abstract class SQLBlock {
    abstract Object call(Connection c) throws SQLException;

    public void close(Statement statement) {
        RubyJdbcConnection.close(statement);
    }

    public void close(ResultSet resultSet) {
        RubyJdbcConnection.close(resultSet);
    }
}
