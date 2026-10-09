
package com.is.secureChatApp.config;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class DatabaseConnectionTest {

    @Bean
    CommandLineRunner testDatabaseConnection(DataSource dataSource) {
        return args -> {
            try (Connection connection = dataSource.getConnection()) {
                System.out.println("================================");
                System.out.println("POSTGRESQL CONNECTION SUCCESSFUL");
                System.out.println(
                        "Database: " +
                                connection.getCatalog()
                );
                System.out.println(
                        "Connected: " +
                                !connection.isClosed()
                );
                System.out.println("================================");
            } catch (SQLException e) {
                System.err.println(
                        "POSTGRESQL CONNECTION FAILED"
                );
                throw e;
            }
        };
    }
}
