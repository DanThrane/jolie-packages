include "registry.iol"
include "admin.iol"
include "string_utils.iol"
include "console.iol"
include "file.iol"
include "zip_utils.iol"
include "time.iol"

include "semver.iol" from "semver"
include "packages.iol" from "packages"
include "utils.iol" from "jpm-utils"
include "authorization.iol" from "authorization"
include "checksum.iol" from "checksum"

execution { concurrent }

define NormalizeRequestUsername {
    toLowerCase@StringUtils(req.username)(req.username)
}

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

dynamic outputPort PeerRegistry {
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

outputPort RegDB {
    Interfaces: IRegistryDatabase
}

embedded {
    Jolie:
        "--conf embed-packages embeds.col packages.pkg" in Packages
}

parameters {
    PUBLIC_LOCATION: string,
    ENABLE_KILL_COMMAND: bool,
    KILL_TOKEN: string,
    FRESH_TOKEN: long,
    DATA_DIR: string,
    TRUSTED_PEERS: void {
        .location[0, *]: string
    }
}

constants {
    CHECKSUM_ALGORITHM = "sha-256"
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
            .sets[0].groupName = singletonGroupName,
            .sets[0].change[0].key = "group." + groupName,
            .sets[0].change[0].right = "super",
            .sets[0].change[0].grant = true
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
            .message = "Not authorized to manage group"
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
define GroupRemoveMember {
    // TODO This should be done in a single database transaction,
    // which we are not. We could probably get away with adding a new op for
    // removing and stripping in a single transaction.

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
    // TODO Check if user is allowed to create packages
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
        .sets[0].groupName = groupName,

        .sets[0].change[0].key = "packages." + packageName,
        .sets[0].change[0].right = "write",
        .sets[0].change[0].grant = true,

        .sets[0].change[1].key = "packages." + packageName,
        .sets[0].change[1].right = "read",
        .sets[0].change[1].grant = true
    })()
}


/**
 * @input groupName: string
 */
define TeamValidateName {
    match@StringUtils(groupName { .regex = "[a-zA-Z0-9_-]*" })(isGood);

    if (isGood == -1) {
        throw(RegistryFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Team names can only contain alpha-numeric " +
                "characters. No spaces allowed"
        })
    }
}

/**
 * @input groupName: string
 * @output groupName: string
 */
define TeamCreateNameSpaced {
    groupName = "teams." + groupName
}

/**
 * @input .known: Map<String, Registry>
 * @input .deps[0, *]: Dependency
 * @throws RegistryFault if dependencies are not from a trusted peer
 */
define ValidateDependenciesLocation {
scope(ValidateDependenciesLocation) {
    ns -> ValidateDependenciesLocation;

    install(IOException =>
        throw(RegistryFault, {
            .type = FAULT_INTERNAL,
            .message = "Unable to contact registry '" + ns.dep.registry + "'"
        })
    );

    ns.dep -> ns.in.deps[ns.i];
    for (ns.i = 0, ns.i < #ns.in.deps, ns.i++) {
        PeerRegistry.location = ns.in.known.(ns.dep.registry).location;
        getPackageInfo@PeerRegistry(ns.dep.name)(ns.info);
        if (#ns.info.results == 0) {
            throw(RegistryFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Could not find needed dependency '" +
                    ns.dep.name + "'. Registry '" + ns.dep.registry + "' " +
                    "returned no results."
            })
        };
        undef(ns.info)
    }
}
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
    println@Console("Ready!")() // Used by testing framework, do not remove
}

main {
    [authenticate(req)(res) {
        NormalizeRequestUsername;
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
        NormalizeRequestUsername;
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

    [createTeam(req)() {
        token = req.token;
        groupName = req.teamName;

        TeamValidateName;
        TeamCreateNameSpaced;
        GroupCreate
    }]

   [addTeamMember(req)() {
        NormalizeRequestUsername;
        token = req.token;
        groupName = req.teamName;
        member = req.username;

        TeamValidateName;
        TeamCreateNameSpaced;

        GroupAddMember
    }]

    [removeTeamMember(req)() {
        NormalizeRequestUsername;
        token = req.token;
        groupName = req.teamName;
        member = req.username;

        TeamValidateName;
        TeamCreateNameSpaced;

        GroupRemoveMember
    }]

    [promoteTeamMember(req)() {
        NormalizeRequestUsername;
        token = req.token;
        groupName = req.teamName;
        currentUser = req.username;

        TeamValidateName;
        TeamCreateNameSpaced;
        GroupRequireSuperPrivileges;

        GroupSingletonName;
        changeGroupRights@Authorization({
            .sets[0].groupName = singletonGroupName,
            .sets[0].change[0].key = "group." + groupName,
            .sets[0].change[0].right = "super",
            .sets[0].change[0].grant = true
        })()
    }]

    [demoteTeamMember(req)() {
        NormalizeRequestUsername;
        token = req.token;
        groupName = req.teamName;
        currentUser = req.username;

        TeamValidateName;
        TeamCreateNameSpaced;

        GroupRequireSuperPrivileges;
        GroupSingletonName;
        changeGroupRights@Authorization({
            .sets[0].groupName = singletonGroupName,
            .sets[0].change[0].key = "group." + groupName,
            .sets[0].change[0].right = "super",
            .sets[0].change[0].grant = false
        })()
    }]

    [listTeamMembers(req)(resp) {
        token = req.token;
        groupName = req.teamName;

        TeamValidateName;
        TeamCreateNameSpaced;
        GroupRequireSuperPrivileges;
        getGroupMembers@Authorization({ .groupName = groupName })(resp)
    }]

    [download(req)(res) {
        packageName -> req.packageName;
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
        getInformationAboutPackageOfVersion@RegDB
            (checkForPackageRequest)(info);

        if (#info.result == 0) {
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
                .type = FAULT_INTERNAL,
                .message = "Internal server error (Could not find .pkg)"
            })
        };

        // Read into message payload
        readFile@File({
            .filename = pkgFileName,
            .format = "binary"
        })(res.payload);
        res.checksum = info.result.checksum
    }]

    [publish(req)(res) {
        // TODO FIXME Keeping the entire package in RAM for the transfer is a
        // big problem. Could easily just start sending a gigantic file and DOS
        // the server easily. Is it even possible to send messages of limited
        // size in Jolie?

        // Update: There is not. This is a clear security vulnerability.
        // This is present in all (Jolie) sodep and http servers

        // Check if package exists. Reject if it does, and user doesn't have
        // rights. If package needs to be created wait for validation.
        packageName = req.package;
        checkIfPackageExists@RegDB({
            .packageName = packageName
        })(packageExists);

        if (packageExists) {
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
            }
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
                    .message = "Package manifest has errors."
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

            // Check if we trust the registries used
            manifestReg -> package.registries[i];
            for (i = 0, i < #package.registries, i++) {
                // Also create a lookup table for registries (used later)
                knownRegistries.(manifestReg.name) << manifestReg;

                found = false;
                for (j = 0, !found && j < #TRUSTED_PEERS.location, j++) {
                    if (manifestReg.location == TRUSTED_PEERS.location[j]) {
                        found = true
                    }
                };

                if (!found) {
                    throw(RegistryFault, {
                        .type = FAULT_BAD_REQUEST,
                        .message = "Untrusted registry: '" +
                            manifestReg.name + "' located at '" +
                            manifestReg.location + "'"
                    })
                }
            };

            knownRegistries.("public") << {
                .name = "public",
                .location = PUBLIC_LOCATION
            };

            // Note we do not need to check the dependency. Packages can only
            // use known registries, and we have already vetted all
            // registries.
            ValidateDependenciesLocation.in.known -> knownRegistries;

            ValidateDependenciesLocation.in.deps -> package.dependencies;
            ValidateDependenciesLocation;

            ValidateDependenciesLocation.in.deps ->
                package.interfaceDependencies;
            ValidateDependenciesLocation;

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

            // Validation is done. If we didn't have a package create a new
            // one. This will fail, if someone else managed to create a package
            // in the mean time. Following this there is no need for a rights
            // check.
            if (!packageExists) {
                packageCreateInput.token = req.token;
                packageCreateInput.name = req.package;
                PackageCreate
            };

            // Insert package into the various databases
            insertRequest.package << package;
            directoryDigest@Checksum({
                .algorithm = CHECKSUM_ALGORITHM,
                .file = temporaryFileName
            })(insertRequest.checksum);
            insertNewPackage@RegDB(insertRequest)();

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

    [transfer(request)(response) {
        scope(s) {
            install(AuthorizationFault =>
                    throw(RegistryFault, s.AuthorizationFault));
            // validate token, token must be fresh to ensure that the user has
            // re-authenticated before performing this
            token = request.token;
            revalidate = true;
            UserGet; // currentUser: string

            // validate that package and team exists
            checkIfPackageExists@RegDB
                ({ .packageName = request.packageName })
                (packageExists);

            if (!packageExists) {
                throw(RegistryFault, {
                    .type = 400,
                    .message = "Unknown package"
                })
            };

            newOwner = "teams." + request.to;
            groupExists@Authorization(newOwner)(newOwnerExists);
            if (!newOwnerExists) {
                throw(RegistryFault, {
                    .type = 400,
                    .message = "Unknown recipient" + newOwner
                })
            };

            // check rights of current user
            resourceName = "packages." + request.packageName;
            rightName = "write";
            foundGroup = null;

            getRightsByToken@Authorization(request.token)(rights);
            foreach (groupName : rights.matrix) {
                group -> rights.matrix.(groupName);
                if (is_defined(group.(resourceName).(rightName))) {
                    if (foundGroup != null) {
                        // There should never be multiple groups with write
                        // rights
                        throw(RegistryFault, {
                            .type = 500,
                            .message = "Internal server fault"
                        })
                    };
                    foundGroup = groupName

                    // Ideally we would break here, but there is no way to
                    // break an foreach early. Instead we just make sure no
                    // other group has the right
                }
            };

            if (foundGroup == null) {
                throw(RegistryFault, {
                    .type = 400,
                    .message = "Unauthorized to perform transfer"
                })
            };

            // update rights, transfering ownership from the original group to
            // the new group
            with (sets[0]) {
                .groupName = foundGroup;
                .change[0].key = resourceName;
                .change[0].right = rightName;
                .change[0].grant = false
            };

            with (sets[1]) {
                .groupName = newOwner;
                .change[0].key = resourceName;
                .change[0].right = rightName;
                .change[0].grant = true
            };

            with (sets[2]) { // ensure new owner has read rights
                .groupName = newOwner;
                .change[0].key = resourceName;
                .change[0].right = "read";
                .change[0].grant = true
            };

            changeRequest.sets -> sets;

            changeGroupRights@Authorization(changeRequest)()
        }
    }]

    [checksum(req)(res) {
        with (infoRequest) {
            .packageName = req.packageName;
            .version << req.version
        };

        getInformationAboutPackageOfVersion@RegDB(infoRequest)(info);
        if (#info.result == 1) {
            res.result = info.result.checksum
        }
    }]

    [ping(echo)(echo) { nullProcess }]

    [kill(token)() {
        if (ENABLE_KILL_COMMAND && token == KILL_TOKEN) {
            exit
        }
    }]
}

