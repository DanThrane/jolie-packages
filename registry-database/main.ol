include "configuration.iol"
include "scripts.iol"
include "database.iol"
include "console.iol"
include "db.iol"

execution { concurrent }

#ext inputPort RegDB {
    Interfaces: IRegistryDatabase
}

constants {
    DEPENDENCY_TYPE_RUNTIME = 0,
    DEPENDENCY_TYPE_INTERFACE = 1
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
    scope (dbInit) {
        install(SQLException =>
            println@Console("Exception when initializing database")();
            valueToPrettyString@StringUtils(dbInit.SQLException)(prettyEx);
            println@Console(prettyEx)();
            exit
        );

        DatabaseConnect;
        scope (findVersion) {
            install(SQLException => version = 0);
            query@Database("SELECT currentVersion FROM meta")(v);
            version = v.row.currentVersion
        };

        for (j = version, j < #ALL_VERSIONS.v, j++) {
            name = ALL_VERSIONS.v[j];
            for (i = 0, i < #INIT_SCRIPTS.(name), i++) {
                update@Database(INIT_SCRIPTS.(name)[i])(ret)
            }
        };

        update@Database("UPDATE meta SET currentVersion = :version" {
            .version = #ALL_VERSIONS.v
        })();

        undef(ret);
        undef(v)
    }
}

/**
 * @input package: Package
 * @input .currDependency: Dependency
 * @input .type: int
 * @output adds insert statement to 'statements'
 */
define DependencyInsert {
    // TODO Cross registry dependencies here!
    ns -> DependencyInsert;
    undef(ns.insertQuery);
    ns.insertQuery = "
        INSERT INTO package_dependency
        (packageName, major, minor, patch, dependency, type, version)
        VALUES (:packageName, :major, :minor, :patch, :dependency,
                :type, :version);
    ";
    ns.insertQuery.packageName = package.name;
    ns.insertQuery.major = package.version.major;
    ns.insertQuery.minor = package.version.minor;
    ns.insertQuery.patch = package.version.patch;
    ns.insertQuery.type = ns.in.type;

    ns.insertQuery.dependency = ns.in.currDependency.name;
    ns.insertQuery.version = ns.in.currDependency.version;
    statements[#statements] << ns.insertQuery
}

init {
    install(RegDBFault => nullProcess);
    DatabaseInit
}

main {
    [query(request)(result) {
        DatabaseConnect;
        databaseQuery = "
            SELECT
              package.packageName,
              package_versions.major,
              package_versions.minor,
              package_versions.patch,
              package_versions.label,
              package_versions.description,
              package_versions.license,
              package_versions.checksum
            FROM
              package, package_versions
            WHERE
              package.packageName LIKE '%' || :q || '%' AND
              package_versions.packageName = package.packageName
            GROUP BY package.packageName
            ORDER BY
              package_versions.major, package_versions.minor,
              package_versions.patch;
        ";
        databaseQuery.q = request.query;
        query@Database(databaseQuery)(databaseResponse);
        result.results << databaseResponse.row
    }]

    [checkIfPackageExists(request)(result) {
        DatabaseConnect;
        if (!is_defined(request.version)) {
            containsQuery = "
                SELECT
                    COUNT(packageName) AS count
                FROM
                    package
                WHERE
                    packageName = :packageName;
            ";
            containsQuery.packageName = request.packageName;
            query@Database(containsQuery)(sqlResponse);
            result = sqlResponse.row.count == 1
        } else {
            containsQuery = "
                SELECT
                  package.packageName AS packageName,
                  major,
                  minor,
                  patch,
                  label,
                  description,
                  license
                FROM
                  package,
                  package_versions
                WHERE
                  package.packageName = :packageName AND
                  package.packageName = package_versions.packageName AND
                  major = :major AND
                  minor = :minor AND
                  patch = :patch;
            ";
            containsQuery.packageName = request.packageName;
            containsQuery.major = request.version.major;
            containsQuery.minor = request.version.minor;
            containsQuery.patch = request.version.patch;

            query@Database(containsQuery)(sqlResponse);
            result = #sqlResponse.row == 1
        }
    }]

    [getInformationAboutPackageOfVersion(request)(result) {
        DatabaseConnect;
        packageQuery = "
            SELECT
              package.packageName AS packageName,
              major,
              minor,
              patch,
              label,
              description,
              license,
              checksum
            FROM
              package,
              package_versions
            WHERE
              package.packageName = :packageName AND
              package.packageName = package_versions.packageName AND
              major = :major AND
              minor = :minor AND
              patch = :patch
        ";
        packageQuery.packageName = request.packageName;
        query@Database(packageQuery)(sqlResponse);
        result.results -> sqlResponse.row
    }]

    [getInformationAboutPackage(request)(result) {
        DatabaseConnect;
        packageQuery = "
            SELECT
              package.packageName AS packageName,
              major,
              minor,
              patch,
              label,
              description,
              license,
              checksum
            FROM
              package,
              package_versions
            WHERE
              package.packageName = :packageName AND
              package.packageName = package_versions.packageName;
        ";
        packageQuery.packageName = request.packageName;
        query@Database(packageQuery)(sqlResponse);
        result.results -> sqlResponse.row
    }]

    [getPackageList()(result) {
        DatabaseConnect;
        packageQuery = "
            SELECT
              package.packageName AS packageName,
              major,
              minor,
              patch,
              label,
              description,
              license
            FROM
              package,
              package_versions
            WHERE
              package.packageName = package_versions.packageName;
        ";
        query@Database(packageQuery)(sqlResponse);
        result.results -> sqlResponse.row
    }]

    [comparePackageWithNewestVersion(request)(result) {
        DatabaseConnect;

        // Returns no rows if input version is the newest, otherwise the newest
        // version
        packageQuery = "
            SELECT
              major,
              minor,
              patch,
              label
            FROM
              package_versions
            WHERE
              packageName = :packageName AND
              (
                (major > :major) OR
                (major = :major AND minor > :minor) OR
                (major = :major AND minor = :minor AND patch > :patch) OR
                (major = :major AND minor = :minor AND patch = :patch)
              )
            ORDER BY
              major DESC,
              minor DESC,
              patch DESC
            LIMIT 1;
        ";
        packageQuery.packageName = request.package.name;
        packageQuery.major = request.package.version.major;
        packageQuery.minor = request.package.version.minor;
        packageQuery.patch = request.package.version.patch;
        packageQuery.label = request.package.version.label;
        query@Database(packageQuery)(sqlResponse);

        if (#sqlResponse.row == 0) {
            result.isNewest = true;
            result.newestVersion << request.package.version
        } else {
            result.isNewest = false;
            result.newestVersion.major = sqlResponse.row.major;
            result.newestVersion.minor = sqlResponse.row.minor;
            result.newestVersion.patch = sqlResponse.row.patch
        }
    }]

    [insertNewPackage(request)() {
        package -> request.package;
        DatabaseConnect;
        scope (insertion) {
            install (SQLException =>
                error.type = FAULT_INTERNAL;
                error.message = "Unable to insert package";
                error.details << insertion.SQLException;
                throw(RegDBFault, error)
            );

            // First we insert a new version entry
            packageInsertion = "
                INSERT INTO package_versions
                    (packageName, major, minor, patch, label, description,
                     license, checksum)
                VALUES
                    (:packageName, :major, :minor, :patch, :label, :description,
                     :license, :checksum);
            ";
            packageInsertion.packageName = package.name;
            packageInsertion.major = package.version.major;
            packageInsertion.minor = package.version.minor;
            packageInsertion.patch = package.version.patch;
            packageInsertion.label = package.version.label;
            packageInsertion.description = package.description;
            packageInsertion.license = package.license;
            packageInsertion.checksum = request.checksum;
            statements[#statements] << packageInsertion;

            // Insert dependencies
            DependencyInsert.in.currDependency -> package.dependencies[i];
            DependencyInsert.in.type = DEPENDENCY_TYPE_RUNTIME;
            for (i = 0, i < #package.dependencies, i++) {
                DependencyInsert
            };

            // Insert interface dependencies
            DependencyInsert.in.currDependency ->
                package.interfaceDependencies[i];
            DependencyInsert.in.type = DEPENDENCY_TYPE_INTERFACE;
            for (i = 0, i < #package.interfaceDependencies, i++) {
                DependencyInsert
            };

            if (#statements > 0) {
                transaction.statement -> statements;
                executeTransaction@Database(transaction)(ret)
            }
        }
    }]

    [createPackage(packageName)() {
        DatabaseConnect;
        scope (insertion) {
            install (SQLException =>
                throw(RegDBFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Package already exists (SQL)"
                })
            );

            insertionRequest = "
                INSERT INTO package (packageName) VALUES (:packageName);
            ";
            insertionRequest.packageName = packageName;
            update@Database(insertionRequest)(ret)
        }
    }]

    [getDependencies(request)(result) {
        scope(s) {
            install(SQLException =>
                throw(RegDBFault, {
                    .type = FAULT_INTERNAL,
                    .message = "Internal Error"
                })
            );

            DatabaseConnect;
            dependencyQuery = "
                SELECT
                  dependency AS name, version, type
                FROM
                  package_dependency
                WHERE
                  packageName = :packageName AND
                  major = :major AND
                  minor = :minor AND
                  patch = :patch;
            ";
            dependencyQuery.packageName = request.package.name;
            dependencyQuery.major = request.package.version.major;
            dependencyQuery.minor = request.package.version.minor;
            dependencyQuery.patch = request.package.version.patch;
            query@Database(dependencyQuery)(sqlResponse);
            row -> sqlResponse.row[i];
            for (i = 0, i < #sqlResponse.row, i++) {
                type = int(row.type);
                undef(row.type);
                if (type == DEPENDENCY_TYPE_RUNTIME) {
                    result.dependencies[#result.dependencies] << row
                } else if (type == DEPENDENCY_TYPE_INTERFACE) {
                    result.interfaceDependencies
                        [#result.interfaceDependencies] << row
                }
            }
        }
    }]
}
