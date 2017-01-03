include "registry.iol"
include "string_utils.iol"
include "console.iol"
include "file.iol"
include "zip_utils.iol"
include "database.iol"
include "semver" "semver.iol"
include "packages" "packages.iol"

execution { concurrent }

inputPort Registry {
    Location: "socket://localhost:12345"
    Protocol: sodep
    Interfaces: IRegistry
}

outputPort Packages {
    Location: "socket://localhost:8888"
    Protocol: sodep
    Interfaces: IPackages
}

constants {
    DATABSE_USERNAME = "",
    DATABASE_PASSWORD = "",
    DATABASE_HOST = "",
    DATABASE_BASE = "/home/dan/registry.db",
    DATABASE_DRIVER = "sqlite"
}

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
            println@Console("Exception when initializing database")()
        );
        DatabaseConnect;
        update@Database("
            CREATE TABLE IF NOT EXISTS package (
                packageName     TEXT    PRIMARY KEY
            );
        ")(ret);

        update@Database("
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
        ")(ret);

        undef(ret)
    }
}

/**
  * @input packageName: string
  * @output packageExists: bool
  */
define PackageCheckIfExists {
    DatabaseConnect;
    containsQuery = "
        SELECT COUNT(packageName) AS count FROM package WHERE packageName = :packageName;
    ";
    containsQuery.packageName = packageName;
    query@Database(containsQuery)(sqlResponse);
    packageExists = sqlResponse.row.count == 1
}

/**
 * @input packageName: string
 */
define PackageCreate {
    DatabaseConnect;
    scope (insertion) {
        install (SQLException => 
            println@Console("We already have one of those?")()
        );

        insertionRequest = "
            INSERT INTO package (packageName) VALUES (:packageName);
        ";
        insertionRequest.packageName = packageName;
        update@Database(insertionRequest)(ret)
    }
}

/**
 * @input packageName: string
 * @output packageInformation: void { 
 *     .packageId: int, 
 *     .packageName: string, 
 *     .major: int, 
 *     .minor: int, 
 *     .patch: int, 
 *     .label?: string, 
 *     .description?: string, 
 *     .license: LicenseIdentifier
 * }
 */
define PackageGetInformation {
    DatabaseConnect;
    packageQuery = "
        SELECT
          package.id          AS packageId,
          package.packageName AS packageName,
          major,
          minor,
          patch,
          label,
          description,
          license
        FROM
          package
          LEFT OUTER JOIN package_versions
            ON package.name = package_versions.packageName
        WHERE
          package.packageName = :packageName;
    ";
    packageQuery.packageName = packageName;
    query@Database(packageQuery)(sqlResponse);
    packageInformation -> sqlResponse.row;
    undef(packageQuery)
}

/**
 * Checks if the 'package' has a version that the registry will allow. 
 * @input package: Package
 * @output isNewest: bool
 * @output newestVersion?: SemVer
 */
define PackageCheckVersion {
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
    packageQuery.packageName = package.name;
    packageQuery.major = package.version.major;
    packageQuery.minor = package.version.minor;
    packageQuery.patch = package.version.patch;
    packageQuery.label = package.version.label;
    query@Database(packageQuery)(sqlResponse);

    if (#sqlResponse.row == 0) {
        isNewest = true
    } else {
        isNewest = false;
        newestVersion.major = sqlResponse.row.major;
        newestVersion.minor = sqlResponse.row.minor;
        newestVersion.patch = sqlResponse.row.patch
    };
    undef(packageQuery)
}

/** 
 * @input package: Package
 */
define PackageInsertVersion {
    DatabaseConnect;
    scope (insertion) {
        install (SQLException => 
            println@Console("Bad!")()
        );

        packageInsertion = "
            INSERT INTO package_versions 
                (packageName, major, minor, patch, label, description, license)
            VALUES 
                (:packageName, :major, :minor, :patch, :label, :description, 
                 :license);
        ";
        packageInsertion.packageName = package.name;
        packageInsertion.major = package.version.major;
        packageInsertion.minor = package.version.minor;
        packageInsertion.patch = package.version.patch;
        packageInsertion.label = package.version.label;
        packageInsertion.description = ""; // TODO Missing description from package
        packageInsertion.license = package.license;
        update@Database(packageInsertion)(sqlResponse);

        undef(packageInsertion);
        undef(sqlResponse);
        undef(packageInformation);
        undef(packageName)
    }
}

init
{
    getFileSeparator@File()(FILE_SEP);
    FOLDER_PACKAGES = "data" + FILE_SEP + "packages";
    FOLDER_WORK = "data" + FILE_SEP + "work";

    mkdir@File(FOLDER_PACKAGES)();
    mkdir@File(FOLDER_WORK)();
    DatabaseInit
}

main
{
    [authenticate(req)(res) {
        res = true;
        res.token = new
    }]

    [createPackage(req)(res) {
        packageName = req.name;
        PackageCheckIfExists;

        if (packageExists) {
            res = false;
            res.message = "Package already exists!"
        } else {
            PackageCreate;
            res = true;
            res.message = "Package created!"
        }
    }]

    [getPackageList(req)(res) {
        results -> res.results;
        for (i = 0, i < #global.packageList, i++) {
            results[#results] << { .name = global.packageList[i] }
        }
    }]

    [getPackageInfo(packageName)(res) {
        PackageCheckIfExists;

        if (packageExists) {
            PackageGetInformation;
            res.package -> packageInformation
        }
    }]

    [publish(req)(res) {
        // TODO FIXME Keeping the entire package in RAM for the transfer is a 
        // big problem. Could easily just start sending a gigantic file and DOS 
        // the server easily. Is it even possible to send messages of limited 
        // size in Jolie? 
        println@Console("Hello, world!")();
        packageName = req.package;
        PackageCheckIfExists;

        if (packageExists) {
            temporaryNameAndLoc = FOLDER_WORK + FILE_SEP + packageName;
            temporaryFileName = temporaryNameAndLoc + ".pkg";
            writeFile@File({ 
                .content = req.payload,
                .filename = temporaryFileName
            })();

            println@Console("Created a file!")();

            readEntry@ZipUtils({ 
                .entry = "package.json", 
                .filename = temporaryFileName
            })(entry);
            if (!is_defined(entry)) {
                res = false;
                res.message = "Package does not contain a package.json file!"
            } else {
                validate@Packages({ .data = entry })(validated);
                report -> validated;
                ValidationCheckForErrors;
                if (hasErrors) {
                    res = false;
                    res.message = "Package has errors."
                } else {
                    package -> validated.package;
                    PackageCheckVersion;
                    if (isNewest) {
                        PackageInsertVersion;
                        baseFolder = FOLDER_PACKAGES + FILE_SEP + package.name;
                        mkdir@File(baseFolder)();
                        rename@File({
                            .filename = temporaryFileName,
                            .to = baseFolder + FILE_SEP + 
                                package.version.major + "_" + 
                                package.version.minor + "_" + 
                                package.version.patch + ".pkg"
                        })();
                        res = true;
                        res.message = "OK"
                    } else {
                        convertToString@SemVer(newestVersion)(versionString);
                        res = false;
                        res.message = "Registry already contains a newer " + 
                            "version of package '" + package.name + 
                            "' of version '" + versionString + "'"
                    }
                }
            }
        } else {
            res = false;
            res.message = "Package not found!"
        }
    }]
}
