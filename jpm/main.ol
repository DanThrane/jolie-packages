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

execution { sequential }

constants
{
    FOLDER_PACKAGES = "jpm_packages",
    REGISTRY_PUBLIC = "socket://localhost:12345"
}

inputPort JPM {
    Location: "local"
    Interfaces: IJPM
}

outputPort Packages {
    Location: "socket://localhost:8888"
    Protocol: sodep
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
        "jpm-downloader" in Downloader {}
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
    
    debug = 0;
    println@Console(debug++)();
    dependencyStack << package.dependencies;
    currDependency -> dependencyStack[0];
    while (#dependencyStack > 0) {
        println@Console("Looking at the next dependency:")();
        value -> currDependency; DebugPrintValue;
        registryName = currDependency.registry;
        name = currDependency.name;
        RegistrySetLocation;
        
        // Lookup package information from the registry
        getPackageInfo@Registry(name)(info);
        if (#info.packages == 0) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unable to resolve package '" + name + "'. " + 
                    "No such package."            
            })
        };
        println@Console(debug++)();

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
            println@Console(debug++)();
            pkgInfo -> info.packages[j];
            for (j = 0, j < #info.packages, j++) {
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
            println@Console(debug++)();
            // Insert resolved dependency
            with (information) {
                .version << sortedVersions.versions[0];
                .registryLocation = Registry.location;
                .registryName = registryName
            };
            println@Console(debug++)();
            resolved << information;
            // Insert dependencies of this dependency on the stack
            // We only do this if we are a runtime dependency.
            if (currDependency.type == DEPENDENCY_TYPE_RUNTIME) {
                dependenciesRequest.packageName = name;
                dependenciesRequest.version << sortedVersions.versions[0];
                getDependencies@Registry(dependenciesRequest)(newDependencies);
                for (i = 0, i < #newDependencies.dependencies, i++) {
                    item << newDependencies.dependencies[i];
                    item.registry = registryName;
                    dependencyStack[#dependencyStack] << item;
                    undef(item)
                }
            };
            println@Console(debug++)();
            undef(allVersions)
        };

        undef(dependencyStack[0])
    }
}

init
{
    // Don't handle ServiceFaults just send them back to the invoker
    install(ServiceFault => nullProcess);
    getFileSeparator@File()(FILE_SEP)
}

main
{
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
                registries[#registries] << currRegistry
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
        exists@File(request.baseDirectory)(baseDirectoryExists);
        if (!baseDirectoryExists) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Base directory does not exist!"
            })
        };

        mkdir@File(baseDirectory + FILE_SEP + request.name)(success);
        if (!success) {
            throw(ServiceFault, {
                .type = FAULT_INTERNAL,
                .message = "Unable to create directory. Does JPM have " + 
                    "permissions to create directory in 'baseDirectory'?"
            })
        };

        packageManifest.name = request.name;
        packageManifest.description = request.description;
        packageManifest.version = "0.1.0";
        packageManifest.private = true;
        packageManifest.authors -> request.authors;
        getJsonString@JsonUtils(packageManifest)(jsonManifest);

        validate@Packages({ .data = jsonManifest })(report);
        if (report.hasErrors) {
            faultInfo.type = FAULT_BAD_REQUEST;
            faultInfo.message = "Input has errors";
            faultInfo.details -> report.items;

            throw(ServiceFault, faultInfo)
        };

        writeFile@File({
            .content = jsonManifest,
            .filename = baseDirectory + FILE_SEP + request.name + FILE_SEP + 
                "package.json"
        })()
    }]

    [start()() {
        PackageRequired;
        nextArgument -> command[#command];

        nextArgument = "joliedev";
        exists@File(global.path + FILE_SEP + FOLDER_PACKAGES)(packagesExists);

        nextArgument = "--pkg-self";
        nextArgument = package.name;

        if (packageExists) {
            nextArgument = "--pkg-folder";
            nextArgument = FOLDER_PACKAGES
        };

        currentDependency -> package.dependencies[i];
        valueToPrettyString@StringUtils(package)(prettyPackage);
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
        
        nextArgument = package.main;

        executionRequest.directory = global.path;
        executionRequest.suppress = false;
        executionRequest.commands -> command;
        joinRequest.piece -> command;
        joinRequest.delimiter = "\n";
        join@StringUtils(joinRequest)(prettyCommand);
        println@Console(prettyCommand)();
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
                value -> installRequest; DebugPrintValue;
                installDependency@Downloader(installRequest)();
                println@Console(dependencyName + " has been installed!")()
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
            })(token)
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
            })(token)
        }
    }]

    [whoami(req)(res) {
        scope (s) {
            install(RegistryFault => throw(ServiceFault, s.RegistryFault));
            registryName = "public";
            if (is_defined(req.registry)) registryName = req.registry;
            RegistrySetLocation;
            whoami@Registry({ .token = req.token })(res)
        }
    }]

    [logout(req)(res) {
        scope (s) {
            install(RegistryFault => throw(ServiceFault, s.RegistryFault));

            registryName = "public";
            if (is_defined(req.registry)) registryName = req.registry;
            RegistrySetLocation;
            logoutRequest << { .token = req.token };
            value -> logoutRequest; DebugPrintValue;
            logout@Registry(logoutRequest)()
        }
    }]
}
