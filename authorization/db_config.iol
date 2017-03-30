include "database.iol"

constants {
    AUTH_DATABASE_USERNAME: string,
    AUTH_DATABASE_PASSWORD: string,
    AUTH_DATABASE_HOST: string,
    AUTH_DATABASE_BASE: string,
    AUTH_DATABASE_DRIVER: string
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

