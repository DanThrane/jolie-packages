constants {
    // Idea is we could use for some kind of migration system
    ALL_VERSIONS = {
        .v[0] = "version0",
        .v[1] = "version1",
        .v[2] = "version2"
    },
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
        ",
        // fix an invalid constraint on package_dependency
        .version1[0] = "
            CREATE TABLE IF NOT EXISTS meta (
                currentVersion TEXT
            );
        ",
        .version1[1] = "
            INSERT OR IGNORE INTO meta (currentVersion) VALUES (0)
        ",
        .version1[2] = "
            CREATE TABLE package_dependency2 (
              packageName TEXT NOT NULL,
              major       INT  NOT NULL,
              minor       INT  NOT NULL,
              patch       INT  NOT NULL,
              dependency  TEXT NOT NULL,
              version     TEXT NOT NULL,
              type        INT  NOT NULL
            );
        ",
        .version1[3] = "
            INSERT INTO package_dependency2
                (packageName, major, minor, patch, dependency, version, type)
            SELECT
                packageName, major, minor, patch, dependency, version, type
            FROM package_dependency
        ",
        .version1[4] = "
            DROP TABLE package_dependency
        ",
        .version1[5] = "
            ALTER TABLE package_dependency2 RENAME TO package_dependency
        ",
        // add checksum field to packages
        .version2[0] = "
            ALTER TABLE package_versions
            ADD COLUMN checksum TEXT;
        "
    }
}

