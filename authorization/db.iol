//
// db.iol
//
// Contains scripts for interacting with the database. This should only
// contain scripts for: connecting, initializing database, migrating data.
// Queries should stlil be defined elsewhere.
//

include "db.sql"

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

define DatabaseInit {
    DatabaseConnect;

    q = "
        CREATE TABLE IF NOT EXISTS User(
            username    TEXT,
            password    TEXT
        );
    ";
    update@Database(q)();


    q = "
        CREATE TABLE IF NOT EXISTS 'user' (
          username TEXT,
          password TEXT,

          PRIMARY KEY (username)
        );
    ";
    update@Database(q)();

    q = "
        CREATE TABLE IF NOT EXISTS 'group' (
          name TEXT,

          PRIMARY KEY (name)
        );
    ";
    update@Database(q)();

    q = "
        CREATE TABLE IF NOT EXISTS group_member (
          user_id  TEXT,
          group_id TEXT,

          FOREIGN KEY (user_id) REFERENCES 'user',
          FOREIGN KEY (group_id) REFERENCES 'group'
        );
    ";
    update@Database(q)();

    q = "
        CREATE TABLE IF NOT EXISTS group_rights (
          group_id TEXT,
          resource TEXT,

          PRIMARY KEY (group_id, resource),
          FOREIGN KEY (group_id) REFERENCES 'group'
        );
    ";
    update@Database(q)();


    q = "
        CREATE TABLE IF NOT EXISTS resource_right (
          group_id TEXT,
          resource TEXT,
          value    TEXT,

          FOREIGN KEY (group_id, resource) REFERENCES group_rights
        );
    ";
    update@Database(q)();

    q = "
        CREATE TABLE IF NOT EXISTS auth_token (
          token     TEXT,
          timestamp DATE,
          user_id   TEXT,

          PRIMARY KEY (token),
          FOREIGN KEY (user_id) REFERENCES 'user'
        );
    ";
}

