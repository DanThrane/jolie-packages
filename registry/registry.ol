include "registry.iol"
include "admin.iol"
include "string_utils.iol"
include "console.iol"
include "file.iol"
include "zip_utils.iol"
include "database.iol"
include "time.iol"
include "semver" "semver.iol"
include "packages" "packages.iol"
include "jpm-utils" "utils.iol"
include "authorization" "authorization.iol"

execution { concurrent }

inputPort Admin {
    Location: "socket://localhost:12346"
    Protocol: sodep
    Interfaces: IAdmin
}

inputPort Registry {
    Location: "socket://localhost:12345"
    Protocol: sodep
    Interfaces: IRegistry
}

outputPort Packages {
    Interfaces: IPackages
}

outputPort Authorization {
    Interfaces: IAuthorization
}

embedded {
    JoliePackage:
        "packages" in Packages {
            inputPort Packages { Location: "local" Protocol: sodep }
        },
        "authorization" in Authorization {
            inputPort Authorization { Location: "local" Protocol: sodep }
        }
}

constants {
    ENABLE_KILL_COMMAND: bool,
    KILL_TOKEN: string,
    DATABSE_USERNAME: string,
    DATABASE_PASSWORD: string,
    DATABASE_HOST: string,
    DATABASE_BASE: string,
    DATABASE_DRIVER: string,
    FRESH_TOKEN: long
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

        update@Database("
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
 * @input package: Package
 */
define PackageInsertDependencies {
    DatabaseConnect;
    currDependency -> package.dependencies[i];
    for (i = 0, i < #package.dependencies, i++) {
        // TODO We cannot allow cross registry dependencies here! 
        // Or can we. I am really not sure. For now let's assume that we 
        // can't do cross-registry dependencies for published packages.

        // It would however make sense for a privately published package to use
        // packages from a default repository. But it really doesn't make sense
        // the other way around.
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
        executeTransaction@Database(transaction)(ret);
        undef(statements);
        undef(insertQuery);
        undef(transaction)
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

/**
 * @input token: string
 * @input revalidate?: bool = false
 * @output currentUser: string
 * @throws RegistryFault when not authorized
 */
define UserGet {
    if (!is_defined(revalidate)) revalidate = false;
    validationRequest.token = token;
    if (revalidate) validationRequest.maxAge = FRESH_TOKEN;
    validate@Authorization(validationRequest)(validationResponse);
    if (!validationResponse) {
        throw(RegistryFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Not authorized"
        })
    };
    currentUser = validationResponse.username;

    undef(validationRequest);
    undef(validationResponse)
}

/**
 * @input currentUser: string
 * @output singletonGroupName: string
 */
define GroupSingletonName {
    singletonGroupName = "users." + currentUser
}

/**
 * Creates a new group with name `groupName`. The `currentUser` will 
 * automatically be added to this group.
 * 
 * @input token: string
 * @input groupName: string
 * @output currentUser: string
 */
define GroupCreate {
    scope (s) {
        install(AuthorizationFault =>
            // TODO For now we just rethrow, but we should probably handle 
            // this a bit better.
            throw(RegistryFault, s.AuthorizationFault)
        );
        // Get current user, create group, add user
        UserGet;
        createGroup@Authorization({ .groupName = groupName })();
        addGroupMembers@Authorization({
            .groupName = groupName,
            .users[0] = currentUser
        })();

        // Grant super privileges to current user for said group
        GroupSingletonName;
        changeGroupRights@Authorization({
            .groupName = singletonGroupName,
            .change[0].key = "group." + groupName,
            .change[0].right = "super",
            .change[0].grant = true
        })()
    }
}

/**
 * @input token: string
 * @input groupName: string
 */
define GroupRequireSuperPrivileges {
    hasAnyOfRights@Authorization({
        .token = token,
        .check[0].key = "group." + groupName,
        .check[0].right = "super"
    })(hasSuperPrivileges);

    if (!hasSuperPrivileges) {
        throw(RegistryFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Not authorized to add members"
        })
    }
}

/**
 * @input token: string
 * @input groupName: string
 * @input member: string
 */
define GroupAddMember {
    scope (s) {
        install(AuthorizationFault =>
            throw(RegistryFault, s.AuthorizationFault)
        );      
        GroupRequireSuperPrivileges;

        // TODO Check if member even exists!
        addGroupMembers@Authorization({
            .groupName = groupName,
            .users[0] = member
        })()
    }
}

/**
 * @input token: string
 * @input groupName: string
 * @input member: string
 */
define GroupeRemoveMember {
    scope (s) {
        install(AuthorizationFault =>
            throw(RegistryFault, s.AuthorizationFault)
        );

        // Remove from group
        GroupRequireSuperPrivileges;
        removeGroupMembers@Authorization({
            .groupName = groupName,
            .users[0] = member
        })();

        // Strip rights associated with the group
        currentUser = member;
        GroupSingletonName;
        revokeRights@Authorization({
            .groupName = singletonGroupName,
            .key = "group." + groupName
        })()
    }
}

define PackageCreate {
    // Check if package exists
    packageName = packageCreateInput.name;
    PackageCheckIfExists;

    if (packageExists) {
        throw(RegistryFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Package already exists"
        })
    };

    // Ensure that our session is valid
    // TODO Check if use is allowed to create packages
    token = packageCreateInput.token;
    UserGet;

    // Insert package into DB
    DatabaseConnect;
    scope (insertion) {
        install (SQLException => 
            throw(RegistryFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Package already exists (SQL)"
            })
        );

        insertionRequest = "
            INSERT INTO package (packageName) VALUES (:packageName);
        ";
        insertionRequest.packageName = packageName;
        update@Database(insertionRequest)(ret)
    };
    
    // Create implicit package maintainer group and insert current user

    // TODO We need to validate package name early. Should probably 
    // create a mechanism for dealing with this user input.
    groupName = "pkg-maintainers." + packageName;
    GroupCreate;
    changeGroupRights@Authorization({
        .groupName = groupName,
        
        .change[0].key = "packages." + packageName,
        .change[0].right = "write",
        .change[0].grant = true,

        .change[1].key = "packages." + packageName,
        .change[1].right = "read",
        .change[1].grant = true
    })()
}

init {
    install(RegistryFault => nullProcess);
    getFileSeparator@File()(FILE_SEP);
    FOLDER_PACKAGES = "data" + FILE_SEP + "packages";
    FOLDER_WORK = "data" + FILE_SEP + "work";
    global.counter = 0;

    mkdir@File(FOLDER_PACKAGES)();
    mkdir@File(FOLDER_WORK)();
    DatabaseInit;

    println@Console("
     _ ____  __  __   ____            _     _              
    | |  _ \\|  \\/  | |  _ \\ ___  __ _(_)___| |_ _ __ _   _ 
 _  | | |_) | |\\/| | | |_) / _ \\/ _` | / __| __| '__| | | |
| |_| |  __/| |  | | |  _ <  __/ (_| | \\__ \\ |_| |  | |_| |
 \\___/|_|   |_|  |_| |_| \\_\\___|\\__, |_|___/\\__|_|   \\__, |
                                |___/                |___/
")();
    println@Console("Ready!")()
}

main {
    [authenticate(req)(res) {
        // TODO We need some clear rules on usernames and passwords. 
        // We need to be sure that a maliciously crafted username won't do any
        // damage in the authorization system.
        scope (s) {
            install(AuthorizationFault =>
                throw(RegistryFault, s.AuthorizationFault)
            );

            authenticate@Authorization(req)(res)
        }
    }]

    [register(req)(res) {
        scope (s) {
            install(AuthorizationFault => 
                throw(RegistryFault, s.AuthorizationFault)
            );
            register@Authorization(req)(res)
        };
        groupName = "users." + req.username;
        createGroup@Authorization({ .groupName = groupName })();
        addGroupMembers@Authorization({ 
            .groupName = groupName,
            .users[0] = req.username
        })()
        // TODO Would be nice if we had default group rights
    }]

    [whoami(req)(res) {
        scope (s) {
            validate@Authorization(req)(out);
            if (!out) {
                throw(RegistryFault, {
                    .type = 0,
                    .message = "Not authorized"
                })
            };
            res = out.username
        }
    }]

    [logout(req)(res) {
        println@Console("Invalidating token: " + req.token)();
        invalidate@Authorization(req.token)()
    }]

    [createPackage(packageCreateInput)(res) {
        PackageCreate
    }]

    [getPackageList(req)(res) {
        // TODO Permissions
        PackageGetAll;
        res.results -> packageInformation
    }]

    [getPackageInfo(packageName)(res) {
        // TODO Permissions
        PackageGetInformation;
        res.packages -> packageInformation
    }]

    [query(request)(response) {
        // TODO Permissions
        DatabaseConnect;
        databaseQuery = "
            SELECT
              package.packageName,
              package_versions.major,
              package_versions.minor,
              package_versions.patch,
              package_versions.label,
              package_versions.description,
              package_versions.license
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
        response.results -> databaseResponse.row
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
            throw(RegistryFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Invalid package name"
            })
        };

        // Check for download permissions
        permissionCheck.check[0].key = "packages.*";
        permissionCheck.check[0].right = "read";
        permissionCheck.check[1].key = "packages." + packageName;
        permissionCheck.check[1].right = "read";
        if (is_defined(req.token)) permissionCheck.token = req.token;
        hasAnyOfRights@Authorization(permissionCheck)(hasDownloadPermission);
        if (!hasDownloadPermission) {
            throw(RegistryFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unauthorized"
            })
        };

        // Check if package exists
        PackageCheckIfExists;
        if (!packageExists) {
            throw(RegistryFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Could not find package"
            })
        };

        // Check if exists internally
        pkgFileName = FOLDER_PACKAGES + FILE_SEP + packageName + 
                FILE_SEP + version.major + "_" + version.minor + "_" + 
                version.patch + ".pkg";

        exists@File(pkgFileName)(pkgExists);
        if (!pkgExists) {
            throw(RegistryFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Internal server error"
            })
        };

        // Read into message payload
        readFile@File({
            .filename = pkgFileName,
            .format = "binary"
        })(res.payload)
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

        if (!packageExists) {
            packageCreateInput.token = req.token;
            packageCreateInput.name = req.package;
            PackageCreate
        };

        hasAnyOfRights@Authorization({
            .token = req.token,
            .check[0].key = "packages." + packageName,
            .check[0].right = "write"
        })(hasWriteRights);
        
        if (!hasWriteRights) {
            throw(RegistryFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unauthorized"
            })
        };

        GetSafeWorkingName;
        temporaryNameAndLoc = FOLDER_WORK + FILE_SEP + temporaryName;
        temporaryFileName = temporaryNameAndLoc + ".pkg";
        writeFile@File({ 
            .content = req.payload,
            .filename = temporaryFileName
        })();

        scope (s) {
            install(RegistryFault =>
                delete@File(temporaryFileName)();
                throw(RegistryFault, s.RegistryFault)
            );

            readEntry@ZipUtils({ 
                .entry = "package.json", 
                .filename = temporaryFileName
            })(entry);

            if (!is_defined(entry)) {
                throw(RegistryFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Package does not contain a package.json file!"
                })
            };

            validate@Packages({ .data = entry })(report);
            if (report.hasErrors) {
                throw(RegistryFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Package has errors."
                })
            };

            package -> report.package;
            if (package.name != packageName) {
                throw(RegistryFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Package names do not match"
                })
            };
    
            if (package.private) {
                throw(RegistryFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Cannot publish private packages"
                })
            };

            PackageCheckVersion;

            if (!isNewest) {
                convertToString@SemVer(newestVersion)(versionString);
                throw(RegistryFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Registry already contains a newer " + 
                        "version of package '" + package.name + 
                        "' of version '" + versionString + "'"
                })
            };

            PackageInsertVersion;
            PackageInsertDependencies;
            baseFolder = FOLDER_PACKAGES + FILE_SEP + package.name;
            mkdir@File(baseFolder)();
            rename@File({
                .filename = temporaryFileName,
                .to = baseFolder + FILE_SEP + 
                    package.version.major + "_" + 
                    package.version.minor + "_" + 
                    package.version.patch + ".pkg"
            })();

            delete@File(temporaryFileName)()
        }
    }]

    [getDependencies(request)(response) {
        scope(s) {
            install(SQLException =>
                println@Console("SQLException in getDependencies!")();
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
            dependencyQuery.packageName = request.packageName;
            dependencyQuery.major = request.version.major;
            dependencyQuery.minor = request.version.minor;
            dependencyQuery.patch = request.version.patch;
            query@Database(dependencyQuery)(sqlResponse);
            for (i = 0, i < sqlResponse.row, i++) {
                sqlResponse.row[i].type = int(sqlResponse.row[i].type)
            };
            response.dependencies -> sqlResponse.row
        }
    }]

    [ping(echo)(echo) {
        nullProcess
    }]

    [kill(token)() {
        if (ENABLE_KILL_COMMAND && token == KILL_TOKEN) {
            exit
        }
    }]
}
