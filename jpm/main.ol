include "jpm.iol"
include "callback.iol"
include "file.iol"
include "json_utils.iol"
include "string_utils.iol"
include "console.iol"
include "packages.iol" from "packages"
include "registry.iol" from "registry"
include "semver.iol" from "semver"
include "utils.iol" from "jpm-utils"
include "downloader.iol" from "jpm-downloader"
include "execution.iol" from "execution"
include "pkg.iol" from "pkg"
include "system.iol" from "system-java"
include "lockfiles.iol"
include "time.iol"

execution { sequential }

constants {
    FOLDER_PACKAGES = "jpm_packages",
    PING_MESSAGE = "ping"
}

parameters {
    REGISTRY_PUBLIC: string
}

inputPort JPM {
    Interfaces: IJPM
}

dynamic outputPort Callback {
    Interfaces: IJPMCallback
    Protocol: sodep
}

outputPort Packages {
    Interfaces: IPackages
}

dynamic outputPort Registry {
    Protocol: sodep
    Interfaces: IRegistry
}

outputPort Downloader {
    Interfaces: IDownloader
}

outputPort LockFiles {
    Interfaces: ILockFiles
}

embedded {
    Jolie:
        "lockfiles.ol" in LockFiles,
        "--conf embedded-cache embeds.col jpm-downloader.pkg" in Downloader,
        "--conf embedded-packages embeds.col packages.pkg" in Packages
}

define TokensSave {
    with (writeRequest) {
        .filename = TOKENS_FILE;
        .content << tokens;
        .format = "json"
    };
    writeFile@File(writeRequest)()
 }

define TokensRequire {
    if (!is_defined(tokens.(Registry.location))) {
        throw(ServiceFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Unauthorized"
        })
    }
}

define PathRequired {
    if (!is_defined(global.path)) {
        throw(ServiceFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "JPM is not attached to a package"
        })
    }
}

/**
 * @input folder: string
 * @output genericPackage: Package
 */
define PackageRequiredInFolder {
    packageFileName = folder + FILE_SEP + "package.json";
    exists@File(packageFileName)(packageExists);
    if (!packageExists) {
        throw(ServiceFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "package.json does not exist at " + folder
        })
    };

    readFile@File({
        .filename = packageFileName,
        .format = "text"
    })(packageJsonAsText);

    validate@Packages({ .data = packageJsonAsText })(report);
    genericPackage << report.package;
    if (report.hasErrors) {
        faultInfo.type = FAULT_BAD_REQUEST;
        faultInfo.message = "package.json has errors at " + folder;
        faultInfo.details << report.items;
        throw(ServiceFault, faultInfo)
    } else {
        genericPackage.registries[#genericPackage.registries] << {
            .name = "public",
            .location = REGISTRY_PUBLIC
        }
    }
}

/**
 * @output package: Package
 */
define PackageRequired {
    PathRequired;
    folder = global.path;
    PackageRequiredInFolder;
    package << genericPackage;
    undef(genericPackage);
    undef(folder)
}

/**
 * @input dependencyName: string
 * @output dependencyPackage: Package
 */
define PackageRequiredInDependency {
    PathRequired;
    folder = global.path + FILE_SEP + FOLDER_PACKAGES + FILE_SEP +
        dependencyName;
    PackageRequiredInFolder;
    dependencyPackage << genericPackage;
    undef(genericPackage);
    undef(folder)
}

/**
 * @input package?: Package
 * @input registryName: string
 */
define RegistrySetLocation {
    _i = i;
    found = false;

    if (is_defined(package)) {
        registries << package.registries
    };

    registries[#registries] << {
        .name = "public",
        .location = REGISTRY_PUBLIC
    };

    for (i = 0, i < #registries && !found, i++) {
        if (registries[i].name == registryName) {
            Registry.location = registries[i].location;
            found = true
        }
    };

    if (!found) {
        throw(ServiceFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Cannot find registry '" + registryName + "'"
        })
    };

    i = _i;
    undef(_i)
}

/**
 * @input ignoreLockfile?: bool
 * @output resolvedDependencies: Map<String, SemVer>
 */
define DependencyTree {
scope(DependencyTree) {
    PackageRequired;

    install(LockFileFault =>
        throw(ServiceFault, DependencyTree.LockFileFault)
    );

    // Open lock file
    open@LockFiles(global.path)();

    // Add all runtime dependencies to the stack
    dependencyStack << package.dependencies;

    // First iterate through runtime dependencies, then interface dependencies
    // When the stack size initially reaches 0, we will push the interface
    // dependencies onto the stack.
    isRuntimeDependency = true;

    // Except if we have no ordinary dependencies, in that case, add all of
    // the interface dependencies now.
    if (#dependencyStack == 0) {
        dependencyStack << package.interfaceDependencies;
        isRuntimeDependency = false
    };

    currDependency -> dependencyStack[0];
    while (#dependencyStack > 0) {
        registryName = currDependency.registry;
        name = currDependency.name;
        RegistrySetLocation;

        // Lookup package information from the registry
        getPackageInfo@Registry(name)(info);
        if (#info.results == 0) {
            close@LockFiles(global.path)();
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unable to resolve package '" + name + "'. " +
                    "No such package."
            })
        };

        resolved -> resolvedDependencies.(currDependency.name);
        if (is_defined(resolved)) {
            // We might have already found this package in a previous
            // iteratation. Check if our expression matches the already
            // selected version.
            convertToString@SemVer(resolved.version)(versionString);
            satisfies@SemVer({
                .version = versionString,
                .range = currDependency.version
            })(versionSatisfied);

            if (!versionSatisfied) {
                close@LockFiles(global.path)();
                throw(ServiceFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Unable to resolve package '" + name +
                        "'. Conflicting versions required."
                })
            }
        } else {
            checkLockRequest = global.path;
            checkLockRequest.dep << currDependency;

            isLocked@LockFiles(checkLockRequest)(lockInformation);
            if (lockInformation && !ignoreLockfile) {
                // Always use the lock file, if available
                with (information) {
                    .version << lockInformation.locked;
                    .registryName = registryName;
                    .registryLocation = Registry.location
                };

                resolved << information
            } else {
                // We need to find the best matching version.
                // Start by finding all versions of this package
                pkgInfo -> info.results[j];
                for (j = 0, j < #info.results, j++) {
                    with (version) {
                        .major = pkgInfo.major;
                        .minor = pkgInfo.minor;
                        .patch = pkgInfo.patch
                    };
                    allVersions[#allVersions] << version
                };

                // Find the best match for our version expression
                sortRequest.versions -> allVersions;
                sortRequest.satisfying = currDependency.version;
                sort@SemVer(sortRequest)(sortedVersions);
                if (#sortedVersions.versions == 0) {
                    close@LockFiles(global.path)();
                    throw(ServiceFault, {
                        .type = FAULT_BAD_REQUEST,
                        .message = "Unable to resolve package '" + name +
                            "'. No version matches expression '" +
                            currDependency.version + "'"
                    })
                };

                // Insert resolved dependency
                with (information) {
                    .version << sortedVersions.versions
                        [#sortedVersions.versions - 1];
                    .registryLocation = Registry.location;
                    .registryName = registryName
                };
                resolved << information;

                // Lock version
                lockRequest = global.path;
                with (lockRequest) {
                    .dep << currDependency;
                    .resolved << information.version
                };
                lock@LockFiles(lockRequest)()
            };

            // Insert dependencies of this dependency on the stack
            dependenciesRequest.packageName = name;
            dependenciesRequest.version << resolved.version;
            getDependencies@Registry(dependenciesRequest)(newDependencies);

            if (isRuntimeDependency) {
                subDependencies -> newDependencies.dependencies
            } else {
                subDependencies -> newDependencies.interfaceDependencies
            };

            for (i = 0, i < #subDependencies, i++) {
                item << subDependencies[i];
                item.registry = registryName;
                item.registryLocation = item.origin;
                undef(item.origin);
                dependencyStack[#dependencyStack] << item;
                undef(item)
            };
            undef(allVersions)
        };

        undef(dependencyStack[0]);

        if (#dependencyStack == 0 && isRuntimeDependency) {
            dependencyStack << package.interfaceDependencies;
            isRuntimeDependency = false
        }
    };

    close@LockFiles(global.path)()
}
}

/**
 * @input .name: string
 * @output .exitCode: int
 */
define EventHandle {
    ns -> EventHandle;
    PackageRequired;
    ns.package -> package;
    if (is_defined(ns.package.events.(ns.in.name))) {
        ns.eventReq.directory = global.path;
        ns.eventReq.suppress = false;
        split@StringUtils(ns.package.events.(ns.in.name) {
            .regex = " "
        })(ns.split);
        ns.eventReq.commands -> ns.split.result;
        execute@Execution(ns.eventReq)(ns.out.exitCode);

        if (ns.out.exitCode != 0) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Script for '" + ns.in.name + "' " +
                    "exited with a non-zero status code (" +
                    ns.out.exitCode + ")"
            })
        }
    }
}

/**
 * @input req.registry: string
 * @output Registry.location: string
 */
define RequireRegistry {
    registryName = "public";
    if (is_defined(req.registry)) registryName = req.registry;
    if (registryName != "public") {
        PackageRequired
    };
    RegistrySetLocation;

    install(IOException =>
        throw(ServiceFault, {
            .type = FAULT_INTERNAL,
            .message = "Unable to contact registry"
        })
    );

    install(RegistryFault => throw(ServiceFault, s.RegistryFault))
}

/**
 * @output Registry.location: string
 * @output token: string
 */
define RequireRegistryAndToken {
    RequireRegistry;
    TokensRequire;
    if (is_defined(tokens.(Registry.location))) {
        token = tokens.(Registry.location)
    }
}

/**
 * @input req
 * @output Registry.location: string
 * @output token: string
 * @output outReq: TeamManagementRequest
 */
define RequireTeamManagement {
    RequireRegistryAndToken;
    outReq.token = token;
    outReq.teamName = req.teamName
}

/**
 * @input req
 * @output Registry.location: string
 * @output token: string
 * @output outReq: TeamMemberManagementRequest
 */
define RequireTeamMemberManagement {
    RequireTeamManagement;
    outReq.username = req.username
}

init {
    // Don't handle ServiceFaults just send them back to the invoker
    install(ServiceFault => nullProcess);
    getFileSeparator@File()(FILE_SEP);
    getUserHomeDirectory@System()(HOME);
    getTemporaryDirectory@System()(TEMP);
    TOKENS_FILE = HOME + FILE_SEP + ".jpmtokens";
    exists@File(TOKENS_FILE)(hasTokens);
    if (hasTokens) {
        readFile@File({
            .filename = TOKENS_FILE,
            .format = "json"
        })(tokens)
    }
}

main {
    // JPM state
    [setCallback(loc)() {
        global.callback = loc
    }]

    [setContext(path)() {
        exists@File(path)(pathExists);
        if (!pathExists) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Path does not exist"
            })
        };
        global.path = path
    }]

    // Local operations working on packages
    [getPackage()(package) {
        PackageRequired
    }]

    [query(request)(response) {
        scope (s) {
            install(ServiceFault => hasPackage = false);
            PackageRequired;
            hasPackage = true
        };

        registries << {
            .name = "public",
            .location = REGISTRY_PUBLIC
        };

        if (hasPackage) {
            currRegistry -> package.registries[i];
            for (i = 0, i < #package.registries, i++) {
                if (currRegistry.name != "public") {
                    registries[#registries] << currRegistry
                }
            }
        };

        scope (queryScope) {
            install(IOException =>
                throw(ServiceFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Unable to connect to registry '" +
                        currRegistry.name + "'"
                })
            );

            queryRequest.query = request.query;
            currRegistry -> registries[i];
            for (i = 0, i < #registries, i++) {
                Callback.location = global.callback;
                jpmEvent@Callback({
                    .type = "query",
                    .data.registry = currRegistry.name
                });
                Registry.location = currRegistry.location;
                query@Registry(queryRequest)(registryResults);
                nextIdx = #response.registries;
                response.registries[nextIdx] << registryResults;
                response.registries[nextIdx].name = currRegistry.name
            }
        }
    }]

    [initializePackage(request)() {
        exists@File(global.path)(global.pathExists);
        if (!global.pathExists) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Base directory does not exist!"
            })
        };

        exists@File(global.path + FILE_SEP + request.name)(packageExists);
        if (packageExists) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Package already exists!"
            })
        };

        mkdir@File(global.path + FILE_SEP + request.name)(success);
        if (!success) {
            throw(ServiceFault, {
                .type = FAULT_INTERNAL,
                .message = "Unable to create directory. Does JPM have " +
                    "permissions to create directory in '" + global.path + "'?"
            })
        };

        packageManifest.name = request.name;
        packageManifest.description = request.description;
        packageManifest.version = "0.1.0";
        packageManifest.private = request.private;
        packageManifest.authors -> request.authors;
        getJsonString@JsonUtils(packageManifest)(jsonManifest);

        validate@Packages({ .data = jsonManifest })(report);
        if (report.hasErrors) {
            faultInfo.type = FAULT_BAD_REQUEST;
            faultInfo.message = "Input has errors";
            faultInfo.details << report.items;

            throw(ServiceFault, faultInfo)
        };

        writeFile@File({
            .content = jsonManifest,
            .filename = global.path + FILE_SEP + request.name + FILE_SEP +
                "package.json"
        })()
    }]

    [start(request)() {
        // Locate our own package
        PackageRequired;
        nextArgument -> command[#command];

        if (!is_defined(package.main)) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Missing 'main' attribute from package manifest!"
            })
        };

        // Setup basic args for interpreter (e.g. trace and debug stuff)
        nextArgument = "joliedev";
        exists@File(global.path + FILE_SEP + FOLDER_PACKAGES)(packagesExists);

        if (is_defined(request.debug)) {
            command[0] = "joliedebug";
            if (request.debug.suspend) {
                nextArgument = "y"
            } else {
                nextArgument = "n"
            };
            nextArgument = "" + request.debug.port
        };

        if (request.trace) {
            nextArgument = "--trace"
        };

        if (request.check) {
            nextArgument = "--check"
        };

        // Configure own package
        nextArgument = "--pkg";
        nextArgument = package.name + ",.," + package.main;

        // Configure dependency packages
        DependencyTree;
        baseDependencyFolder = FOLDER_PACKAGES + FILE_SEP;
        foreach (dependencyName : resolvedDependencies) {
            PackageRequiredInDependency;
            nextArgument = "--pkg";
            definition = dependencyName + "," +
                baseDependencyFolder + dependencyName;
            if (is_defined(dependencyPackage.main)) {
                definition += "," + dependencyPackage.main
            };
            nextArgument = definition;
            undef(dependencyPackage)
        };

        // Configuration (if available)
        if (is_defined(request.config)) {
            nextArgument = "--conf";
            nextArgument = request.config.profile;
            nextArgument = request.config.file
        };

        // Add entry-point (i.e. this package)
        nextArgument = package.name + ".pkg";

        // Arguments to program
        if (is_defined(request.args)) {
            for (i = 0, i < #request.args, i++) {
                nextArgument = request.args[i]
            }
        };

        // Ready to execute. Send out event
        EventHandle.in.name = "pre-start";
        EventHandle;

        // Prepare execution of package
        executionRequest.directory = global.path;
        executionRequest.suppress = false;
        executionRequest.commands -> command;
        joinRequest.piece -> command;
        joinRequest.delimiter = " \\\n    ";
        join@StringUtils(joinRequest)(prettyCommand);

        if (request.isVerbose) {
            Callback.location = global.callback;
            callback.type = "info";
            callback.data = "Start command:\n" + prettyCommand;
            jpmEvent@Callback(callback)
        };

        execute@Execution(executionRequest)();

        // Execution is done. Send out event
        EventHandle.in.name = "post-start";
        EventHandle
    }]

    [dependencyTree()() {
        DependencyTree
    }]

    [installDependencies()() {
        EventHandle.in.name = "pre-install";
        EventHandle;

        DependencyTree;

        Callback.location = global.callback;
        dependencyInformation -> resolvedDependencies.(dependencyName);
        foreach (dependencyName : resolvedDependencies) {
            callback.type = "download-begin";
            callback.data.name = dependencyName;
            callback.data.info << dependencyInformation;
            jpmEvent@Callback(callback);

            scope (installation) {
                install(DownloaderFault =>
                    throw(ServiceFault, installation.DownloaderFault)
                );

                with (installRequest) {
                    .major = dependencyInformation.version.major;
                    .minor = dependencyInformation.version.minor;
                    .patch = dependencyInformation.version.patch;
                    .name = dependencyName;
                    .registryLocation = dependencyInformation.registryLocation;
                    .targetPackage = global.path
                };
                regLocation = dependencyInformation.registryLocation;
                if (is_defined(tokens.(regLocation))) {
                    installRequest.token = tokens.(regLocation)
                };
                installDependency@Downloader(installRequest)()
            };

            callback.type = "download-end";
            jpmEvent@Callback(callback)
        };

        EventHandle.in.name = "post-install";
        EventHandle
    }]

    [upgrade()() {
        ignoreLockfile = true;
        DependencyTree
    }]

    [publish(req)(res) {
        scope (s) {
            install(RegistryFault =>
                throw(ServiceFault, s.RegistryFault)
            );
            PackageRequired;
            if (package.private) {
                throw(ServiceFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Cannot publish private packages"
                })
            };

            registryName = "public";
            if (is_defined(req.registry)) registryName = req.registry;
            RegistrySetLocation;

            TokensRequire;

            EventHandle.in.name = "pre-publish";
            EventHandle;

            temporaryLocation = TEMP + FILE_SEP;
            pkgRequest.zipLocation = temporaryLocation;
            pkgRequest.packageLocation = global.path;
            pkgRequest.name = package.name;
            pack@Pkg(pkgRequest)();

            readFile@File({
                .filename = temporaryLocation + package.name + ".pkg",
                .format = "binary"
            })(payload);

            publish@Registry({
                .package = package.name,
                .payload = payload,
                .token = tokens.(Registry.location)
            })();

            EventHandle.in.name = "post-publish";
            EventHandle
        }
    }]

    // Cache
    [clearCache()() { clearCache@Downloader()() }]

    // Authentication
    [authenticate(req)(token) {
        scope (s) {
            RequireRegistry;

            authenticate@Registry({
                .username = req.username,
                .password = req.password
            })(token);

            tokens.(Registry.location) = token;
            TokensSave
        }
    }]

    [register(req)(token) {
        scope (s) {
            RequireRegistry;

            register@Registry({
                .username = req.username,
                .password = req.password
            })(token);

            tokens.(Registry.location) = token;
            TokensSave
        }
    }]

    [whoami(req)(res) {
        scope (s) {
            RequireRegistryAndToken;
            whoami@Registry({ .token = token })(res)
        }
    }]

    [logout(req)(res) {
        scope (s) {
            RequireRegistryAndToken;
            logout@Registry({ .token = token })();
            undef(tokens.(Registry.location));
            TokensSave
        }
    }]

    // Debugging
    [ping(req)() {
        scope(s) {
            RequireRegistry;
            ping@Registry(PING_MESSAGE)(output);
            if (PING_MESSAGE != output) {
                throw(ServiceFault, {
                    .type = FAULT_INTERNAL,
                    .message = "Unable to contact registry"
                })
            }
        }
    }]

    // Team management
    [addTeamMember(req)() {
        scope(s) {
            RequireTeamMemberManagement;
            addTeamMember@Registry(outReq)()
        }
    }]

    [removeTeamMember(req)() {
        scope (s) {
            RequireTeamMemberManagement;
            removeTeamMember@Registry(outReq)()
        }
    }]

    [promoteTeamMember(req)() {
        scope (s) {
            RequireTeamMemberManagement;
            promoteTeamMember@Registry(outReq)()
        }
    }]

    [demoteTeamMember(req)() {
        scope (s) {
            RequireTeamMemberManagement;
            demoteTeamMember@Registry(outReq)()
        }
    }]

    [createTeam(req)() {
        scope (s) {
            RequireTeamManagement;
            createTeam@Registry(outReq)()
        }
    }]

    [listTeamMembers(req)(res) {
        scope (s) {
            RequireTeamManagement;
            listTeamMembers@Registry(outReq)(res)
        }
    }]

    [transfer(req)(res) {
        scope (s) {
            PackageRequired;
            RequireRegistryAndToken;

            transferRequest.packageName = package.name;
            transferRequest.to = req.to;
            transferRequest.token = token;
            transfer@Registry(transferRequest)()
        }
    }]
}

