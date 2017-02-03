constants {
    // Idea is we could use for some kind of migration system
    DB_VERSION = "version0",
    INIT_SCRIPTS = {
        .version0[0] = "
            CREATE TABLE IF NOT EXISTS package (
                packageName     TEXT    PRIMARY KEY
            );
        ",
        .version0[1] = "
            CREATE TABLE IF NOT EXISTS package_versions (
                packageName TEXT NOT NULL,
                major       INTEGER NOT NULL,
                minor       INTEGER NOT NULL,
                patch       INTEGER NOT NULL,
                label       TEXT,
                description TEXT,
                license     TEXT    NOT NULL,
                FOREIGN KEY (packageName) REFERENCES package
            );
        ",
        .version0[2] = "
            CREATE TABLE IF NOT EXISTS package_dependency (
              packageName TEXT NOT NULL,
              major       INT  NOT NULL,
              minor       INT  NOT NULL,
              patch       INT  NOT NULL,
              dependency  TEXT NOT NULL,
              version     TEXT NOT NULL,
              type        INT  NOT NULL,
              PRIMARY KEY (packageName, major, minor, patch)
            );
        "
    }
}
