include "registry.iol"
include "string_utils.iol"
include "console.iol"
include "file.iol"
include "zip_utils.iol"
include "database.iol"
include "time.iol"
include "semver" "semver.iol"
include "packages" "packages.iol"

execution { concurrent }

inputPort Registry {
    Location: "socket://localhost:12346"
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
            println@Console("Exception when initializing database")();
            exit 
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
  * @input version?: SemVer
  * @output packageExists: bool
  */
define PackageCheckIfExists {
    DatabaseConnect;
    if (!is_defined(version)) {
        containsQuery = "
            SELECT COUNT(packageName) AS count FROM package WHERE packageName = :packageName;
        ";
        containsQuery.packageName = packageName;
        query@Database(containsQuery)(sqlResponse);
        packageExists = sqlResponse.row.count == 1;

        undef(sqlResponse);
        undef(containsQuery)
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
        containsQuery.packageName = packageName;
        containsQuery.major = version.major;
        containsQuery.minor = version.minor;
        containsQuery.patch = version.patch;
        
        query@Database(containsQuery)(sqlResponse);
        packageExists = #sqlResponse.row == 1;

        undef(sqlResponse);
        undef(containsQuery)
    }
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
 * @output packageInformation[0, *]: PackageInformation
 */
define PackageGetInformation {
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
    packageInformation -> sqlResponse.row;
    undef(packageQuery)
}

/**
 * @output packageInformation[0, *]: PackageInformation
 */
define PackageGetAll {
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
    packageInformation -> sqlResponse.row
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

/**
 * Returns a unique safe working name
 * @output temporaryName: string
 */
define GetSafeWorkingName {
    getCurrentTimeMillis@Time()(time);
    synchronized(counterLock){
        suffix = global.counter;
        global.counter = global.counter + 1
    };
    temporaryName = time + "_" + suffix
}

init
{
    getFileSeparator@File()(FILE_SEP);
    FOLDER_PACKAGES = "data" + FILE_SEP + "packages";
    FOLDER_WORK = "data" + FILE_SEP + "work";
    global.counter = 0;

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
        PackageGetAll;
        res.results -> packageInformation
    }]

    [getPackageInfo(packageName)(res) {
        PackageGetInformation;
        res.packages -> packageInformation
    }]

    [download(req)(res) {
        packageName -> req.packageIdentifier;
        version -> req.version;

        // Check to make sure package name is safe.
        // Technically this should be caught be the mere existance of the 
        // package in the database, but downloading from relative paths would 
        // be _very_ bad. So we check just to be sure.
        match@StringUtils(packageName { .regex = "[a-zA-Z0-9_-]*" })(isGood);
        
        if (isGood != 1) {
            res = false;
            res.message = "Invalid name"
        } else {
            PackageCheckIfExists;
            if (!packageExists) {
                res = false;
                res.message = "Could not find package"
            } else {
                pkgFileName = FOLDER_PACKAGES + FILE_SEP + packageName + 
                        FILE_SEP + version.major + "_" + version.minor + "_" + 
                        version.patch + ".pkg";

                exists@File(pkgFileName)(pkgExists);
                if (!pkgExists) {
                    res = false;
                    res.message = "Internal server error"
                } else {
                    res = true;
                    res.message = "OK";

                    readFile@File({
                        .filename = pkgFileName,
                        .format = "binary"
                    })(res.payload)
                }
            }
        }
    }]

    [publish(req)(res) {
        // TODO FIXME Keeping the entire package in RAM for the transfer is a 
        // big problem. Could easily just start sending a gigantic file and DOS 
        // the server easily. Is it even possible to send messages of limited 
        // size in Jolie?

        // Update: There is not. This is a clear security vulnerability. 
        // This is present in all (Jolie) sodep and http servers
        packageName = req.package;
        PackageCheckIfExists;

        if (packageExists) {
            GetSafeWorkingName;
            temporaryNameAndLoc = FOLDER_WORK + FILE_SEP + temporaryName;
            temporaryFileName = temporaryNameAndLoc + ".pkg";
            writeFile@File({ 
                .content = req.payload,
                .filename = temporaryFileName
            })();

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
                if (report.hasErrors) {
                    res = false;
                    res.message = "Package has errors."
                } else {
                    package -> validated.package;

                    if (package.name != packageName) {
                        res = false;
                        res.message = "Package names do not match"
                    } else {
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
            };
            delete@File(temporaryFileName)()
        } else {
            res = false;
            res.message = "Package not found!"
        }
    }]
}
