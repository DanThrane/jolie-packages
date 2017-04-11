include "database.iol"

init {
    // TODO Change if syntax is approved
    AUTH_DATABASE_USERNAME -> global.params.AUTH_DATABASE_USERNAME;
    AUTH_DATABASE_PASSWORD -> global.params.AUTH_DATABASE_PASSWORD;
    AUTH_DATABASE_HOST -> global.params.AUTH_DATABASE_HOST;
    AUTH_DATABASE_BASE -> global.params.AUTH_DATABASE_BASE;
    AUTH_DATABASE_DRIVER -> global.params.AUTH_DATABASE_DRIVER
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

