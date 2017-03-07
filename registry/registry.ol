include "registry.iol"
include "admin.iol"
include "string_utils.iol"
include "console.iol"
include "file.iol"
include "zip_utils.iol"
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

ext outputPort Authorization {
    Interfaces: IAuthorization
}

ext outputPort RegDB {
    Interfaces: IRegistryDatabase
}

embedded {
    JoliePackage:
        "packages" in Packages {
            inputPort Packages { Location: "local" Protocol: sodep }
        }
}

constants {
    ENABLE_KILL_COMMAND: bool,
    KILL_TOKEN: string,
    FRESH_TOKEN: long,
    DATA_DIR: string
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
    checkIfPackageExists@RegDB({
        .packageName = packageName
    })(packageExists);

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
    scope (s) {
        install(RegDBFault => throw(RegistryFault, s.RegDBFault));
        createPackage@RegDB(packageName)()
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
    FOLDER_PACKAGES = DATA_DIR + FILE_SEP + "packages";
    FOLDER_WORK = DATA_DIR + FILE_SEP + "work";
    global.counter = 0;

    mkdir@File(FOLDER_PACKAGES)();
    mkdir@File(FOLDER_WORK)();

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
        invalidate@Authorization(req.token)()
    }]

    [createPackage(packageCreateInput)() { PackageCreate }]

    [getPackageList(req)(res) {
        // TODO Permissions
        getPackageList@RegDB()(res)
    }]

    [getPackageInfo(packageName)(res) {
        // TODO Permissions
        getInformationAboutPackage@RegDB({ .packageName = packageName })(res)
    }]

    [query(request)(response) {
        // TODO Permissions
        query@RegDB(request)(response)
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
        with (checkForPackageRequest) {
            .packageName = packageName;
            .version << version
        };
        checkIfPackageExists@RegDB(checkForPackageRequest)(packageExists);

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
                .message = "Internal server error (Could not find .pkg)"
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

        //
        // Automatically create package if it does not already exist.
        //
        // This will also assign the correct rights to the user making the
        // request.
        //
        packageName = req.package;
        checkIfPackageExists@RegDB({
            .packageName = packageName
        })(packageExists);

        if (!packageExists) {
            packageCreateInput.token = req.token;
            packageCreateInput.name = req.package;
            PackageCreate
        };

        // Check user permissions
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

        // Receive file upload and write to temporary location
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

            install(RegDBFault =>
                delete@File(temporaryFileName)();
                throw(RegistryFault, s.RegDBFault)
            );

            // Validate package manfiest
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

            // Check that version is OK. We do not allow downgrading versions
            verCheckReq.package.name = package.name;
            verCheckReq.package.version << package.version;
            comparePackageWithNewestVersion@RegDB(verCheckReq)(verCheckResp);

            if (!verCheckResp.isNewest) {
                convertToString@SemVer(verCheckResp.newestVersion)
                    (versionString);
                throw(RegistryFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Registry already contains a newer " +
                        "version of package '" + package.name +
                        "' of version '" + versionString + "'"
                })
            };

            // Insert package into the various databases
            insertNewPackage@RegDB(package)();

            baseFolder = FOLDER_PACKAGES + FILE_SEP + package.name;
            mkdir@File(baseFolder)();
            rename@File({
                .filename = temporaryFileName,
                .to = baseFolder + FILE_SEP +
                    package.version.major + "_" +
                    package.version.minor + "_" +
                    package.version.patch + ".pkg"
            })()
        }
    }]

    [getDependencies(request)(response) {
        scope (s) {
            install(RegDBFault => throw(RegistryFault, s.RegDBFault));
            depRequest.package.name = request.packageName;
            depRequest.package.version << request.version;
            getDependencies@RegDB(depRequest)(response)
        }
    }]

    [ping(echo)(echo) { nullProcess }]

    [kill(token)() {
        if (ENABLE_KILL_COMMAND && token == KILL_TOKEN) {
            exit
        }
    }]
}
