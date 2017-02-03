include "configuration.iol"
include "scripts.iol"
include "database.iol"

define DatabaseConnect {
    with (connectionInfo) {
        .username = DATABSE_USERNAME;
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
            exit 
        );

        DatabaseConnect;
        for (i = 0, i < #INIT_SCRIPTS.(DB_VERSION), i++) {
            update@Database(INIT_SCRIPTS.(DB_VERSION)[i])(ret)
            // TODO Validate ret
        };
        undef(ret)
    }
}

init {
    DatabaseInit
}

main {
    [query(request)(result) {
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
              package.packageName = :packageName AND
              package.packageName = package_versions.packageName;
        ";
        packageQuery.packageName = packageName;
        query@Database(packageQuery)(sqlResponse);
        result.packageInformation << sqlResponse.row
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
            result.packageExists = sqlResponse.row.count == 1
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
            result.packageExists = #sqlResponse.row == 1
        }
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
              license
            FROM
              package,
              package_versions
            WHERE
              package.packageName = :packageName AND
              package.packageName = package_versions.packageName;
        ";
        packageQuery.packageName = request.packageName;
        query@Database(packageQuery)(sqlResponse);
        result.packageInformation -> sqlResponse.row
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
        result.packageInformation -> sqlResponse.row
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
            reuslt.isNewest = true;
            result.newestVersion << request.version
        } else {
            result.isNewest = false;
            result.newestVersion.major = sqlResponse.row.major;
            result.newestVersion.minor = sqlResponse.row.minor;
            result.newestVersion.patch = sqlResponse.row.patch
        }
    }]

    [insertNewPackage(package)() {
        DatabaseConnect;
        scope (insertion) {
            install (SQLException => 
                throws(RegDBFault, {
                    .type = FAULT_INTERNAL,
                    .message = "Unable to insert package"
                })
            );

            // First we insert a new version entry
            packageInsertion = "
                INSERT INTO package_versions 
                    (packageName, major, minor, patch, label, description, 
                     license)
                VALUES 
                    (:packageName, :major, :minor, :patch, :label, :description, 
                     :license);
            ";
            packageInsertion.packageName = package.name;
            packageInsertion.major = package.version.major;
            packageInsertion.minor = package.version.minor;
            packageInsertion.patch = package.version.patch;
            packageInsertion.label = package.version.label;
            // TODO Missing description from package
            packageInsertion.description = ""; 
            packageInsertion.license = package.license;
            statements[#statements] << packageInsertion;
            
            // Insert dependencies
            currDependency -> package.dependencies[i];
            for (i = 0, i < #package.dependencies, i++) {
                // TODO Cross registry dependencies here! 
                insertQuery = "
                    INSERT INTO package_dependency
                    (packageName, major, minor, patch, dependency, type, version)
                    VALUES (:packageName, :major, :minor, :patch, :dependency, 
                            :type, :version); 
                ";
                insertQuery.packageName = package.name;
                insertQuery.major = package.version.major;
                insertQuery.minor = package.version.minor;
                insertQuery.patch = package.version.patch;
                insertQuery.type = currDependency.type;

                insertQuery.dependency = currDependency.name;
                insertQuery.version = currDependency.version;
                statements[#statements] << insertQuery
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
                });
                value -> s.SQLException; DebugPrintValue
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
            for (i = 0, i < sqlResponse.row, i++) {
                sqlResponse.row[i].type = int(sqlResponse.row[i].type)
            };
            response.dependencies -> sqlResponse.row
        }
    }]
}
