include "database.iol"

parameters {
    AUTH_DATABASE_USERNAME: undefined,
    AUTH_DATABASE_PASSWORD: undefined,
    AUTH_DATABASE_HOST: undefined,
    AUTH_DATABASE_BASE: undefined,
    AUTH_DATABASE_DRIVER: undefined
}

define DatabaseConnect {
    if (!DatabaseConnect.connected) {
        DatabaseConnect.connected = true;
        with (connectionInfo) {
            .username = AUTH_DATABASE_USERNAME;
            .password = AUTH_DATABASE_PASSWORD;
            .host = AUTH_DATABASE_HOST;
            .database = AUTH_DATABASE_BASE;
            .driver = AUTH_DATABASE_DRIVER
        };
        connect@Database(connectionInfo)();
        undef(connectionInfo)
    }
}

