include "database.iol"

constants {
    DATABASE_USERNAME: string,
    DATABASE_PASSWORD: string,
    DATABASE_HOST: string,
    DATABASE_BASE: string,
    DATABASE_DRIVER: string
}

define DatabaseConnect {
    with (connectionInfo) {
        .username = DATABASE_USERNAME;
        .password = DATABASE_PASSWORD;
        .host = DATABASE_HOST;
        .database = DATABASE_BASE;
        .driver = DATABASE_DRIVER
    };
    connect@Database(connectionInfo)();
    undef(connectionInfo)
}

