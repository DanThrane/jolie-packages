include "jpm.iol"
include "file.iol"
include "json_utils.iol"
include "string_utils.iol"
include "console.iol"
include "packages" "packages.iol"
include "registry" "registry.iol"
include "semver" "semver.iol"
include "jpm-utils" "utils.iol"
include "jpm-downloader" "downloader.iol"
include "execution" "execution.iol"
include "pkg" "pkg.iol"
include "system-java" "system.iol"

execution { sequential }

constants {
    FOLDER_PACKAGES = "jpm_packages",
    REGISTRY_PUBLIC: string
}

inputPort JPM {
    Location: "local"
    Interfaces: IJPM
}

outputPort Packages {
    Interfaces: IPackages
}

outputPort Registry {
    Protocol: sodep
    Interfaces: IRegistry
}

outputPort Downloader {
    Interfaces: IDownloader
}

embedded {
    JoliePackage:
        "jpm-downloader" in Downloader,
        "packages" in Packages {
            inputPort Packages { Location: "local" Protocol: sodep }
            // TODO Shoudln't we allow no protocol?
        }
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
 * @output resolvedDependencies: Map<String, SemVer>
 */
define DependencyTree {
    PackageRequired;

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
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unable to resolve package '" + name + "'. " +
                    "No such package."
            })
        };

        resolved -> resolvedDependencies.(currDependency.name);
        if (is_defined(resolved)) {
            // Check if our expression matches the already selected version
            convertToString@SemVer(resolved.version)(versionString);
            satisfies@SemVer({
                .version = versionString,
                .range = currDependency.version
            })(versionSatisfied);

            if (!versionSatisfied) {
                throw(ServiceFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Unable to resolve package '" + name +
                        "'. Conflicting versions required."
                })
            }
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

            // Insert dependencies of this dependency on the stack
            dependenciesRequest.packageName = name;
            dependenciesRequest.version << sortedVersions.versions[0];
            getDependencies@Registry(dependenciesRequest)(newDependencies);

            if (isRuntimeDependency) {
                subDependencies -> newDependencies.dependencies
            } else {
                subDependencies -> newDependencies.interfaceDependencies
            };

            for (i = 0, i < #subDependencies, i++) {
                item << subDependencies[i];
                item.registry = registryName;
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
    }
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

    [pkgInfo()(package) {
        PackageRequired
    }]

    [start(request)() {
        PackageRequired;
        nextArgument -> command[#command];

        if (!is_defined(package.main)) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Missing 'main' attribute from package manifest!"
            })
        };

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

        isDeploying = is_defined(request.deployment);

        if (isDeploying) {
            nextArgument = "--pkg-root";
            nextArgument = package.name;
            nextArgument = "--main." + package.name;
            nextArgument = global.path + FILE_SEP + package.main
        };

        // TODO package-self and main entry for self

        if (packageExists) {
            nextArgument = "--pkg-folder";
            nextArgument = FOLDER_PACKAGES
        };

        currentDependency -> package.dependencies[i];
        for (i = 0, i < #package.dependencies, i++) {
            dependencyName = currentDependency.name;
            PackageRequiredInDependency;
            if (is_defined(dependencyPackage.main)) {
                nextArgument = "--main." + dependencyName;
                nextArgument = global.path + FILE_SEP + FOLDER_PACKAGES +
                    FILE_SEP + dependencyName +
                    FILE_SEP + dependencyPackage.main
            };
            undef(dependencyPackage)
        };

        if (isDeploying) {
            nextArgument = "--deploy";
            nextArgument = request.deployment.profile;
            nextArgument = request.deployment.file
        } else {
            nextArgument = package.main
        };

        if (is_defined(request.args)) {
            for (i = 0, i < #request.args, i++) {
                nextArgument = request.args[i]
            }
        };

        executionRequest.directory = global.path;
        executionRequest.suppress = false;
        executionRequest.commands -> command;
        joinRequest.piece -> command;
        joinRequest.delimiter = "\n";
        join@StringUtils(joinRequest)(prettyCommand);

        if (request.isVerbose) {
            value -> command; DebugPrintValue;
            println@Console(prettyCommand)()
        };
        execute@Execution(executionRequest)()
    }]

    [installDependencies()() {
        DependencyTree;
        println@Console("Got dependency tree:")();
        value -> resolvedDependencies; DebugPrintValue;

        dependencyInformation -> resolvedDependencies.(dependencyName);
        foreach (dependencyName : resolvedDependencies) {
            scope (installation) {
                install(DownloaderFault =>
                    println@Console("Failed to download dependency '" +
                            dependencyName + "'")();
                    value -> installation.DownloaderFault; DebugPrintValue
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
            }
        }
    }]

    [authenticate(req)(token) {
        scope (s) {
            install(RegistryFault => throw(ServiceFault, s.RegistryFault));

            registryName = "public";
            if (is_defined(req.registry)) {
                registryName = req.registry
            };
            RegistrySetLocation;
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
            install(RegistryFault => throw(ServiceFault, s.RegistryFault));

            registryName = "public";
            if (is_defined(req.registry)) registryName = req.registry;
            RegistrySetLocation;
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
            install(RegistryFault => throw(ServiceFault, s.RegistryFault));
            registryName = "public";
            if (is_defined(req.registry)) registryName = req.registry;
            RegistrySetLocation;

            TokensRequire;
            whoami@Registry({
                .token = tokens.(Registry.location)
            })(res)
        }
    }]

    [logout(req)(res) {
        scope (s) {
            install(RegistryFault => throw(ServiceFault, s.RegistryFault));

            registryName = "public";
            if (is_defined(req.registry)) registryName = req.registry;
            RegistrySetLocation;

            TokensRequire;
            logout@Registry({
                .token = tokens.(Registry.location)
            })();

            undef(tokens.(Registry.location));
            TokensSave
        }
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
            })()
        }
    }]

    [clearCache()() { clearCache@Downloader()() }]

    [ping(registryName)() {
        if (registryName != "public") {
            PackageRequired
        };
        scope (s) {
            install(IOException =>
                throw(ServiceFault, {
                    .type = FAULT_INTERNAL,
                    .message = "Unable to contact registry"
                })
            );
            RegistrySetLocation;
            pingMessage = "ping";
            ping@Registry(pingMessage)(output);
            if (pingMessage != output) {
                throw(ServiceFault, {
                    .type = FAULT_INTERNAL,
                    .message = "Unable to contact registry"
                })
            }
        }
    }]
}
