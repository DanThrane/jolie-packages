include "jpm.iol"
include "file.iol"
include "json_utils.iol"
include "string_utils.iol"
include "console.iol"
include "packages" "packages.iol"
include "registry" "registry.iol"
include "semver" "semver.iol"
include "jpm-utils" "utils.iol"

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
        faultInfo.details -> report.items;
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
 * @input package: Package
 * @input registryName: string
 */
define RegistrySetLocation {
    _i = i;
    found = false;
    for (i = 0, i < #package.registries && !found, i++) {
        if (package.registries[i].name == registryName) {
            Registry.location = package.registries[i].location;
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
    // TODO Dependencies of dependencies

    // It would be very nice if we could ask the registry for this information.
    // This would require us to insert these into the database as we publish
    // new versions.

    // Alternatively we can download these as we figure them out, and then 
    // simply read off the dependencies we get. This approach doesn't seem quite
    // as elegant. But might prove to be easier.
    currDependency -> package.dependencies[i];
    for (i = 0, i < #package.dependencies, i++) {
        registryName = currDependency.registry;
        name = currDependency.name;
        RegistrySetLocation;
        getPackageInfo@Registry(name)(info);
        if (#info.packages == 0) {
            throw(ServiceFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unable to resolve package '" + name + "'. " + 
                    "No such package."            
            })
        } else {
            resolved -> resolvedDependencies.(currDependency.name);
            if (is_defined(resolved)) {
                convertToString@SemVer(resolved)(versionString);
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
                pkgInfo -> info.packages[j];
                for (j = 0, j < #info.packages, j++) {
                    nextIdx = allVersions[#allVersions];
                    with (allVersions[nextIdx]) {
                        .major = pkgInfo.major;
                        .minor = pkgInfo.minor;
                        .patch = pkgInfo.patch
                    }
                };
                sortRequest.versions -> allVersions;
                sortRequest.satisfying = currDependency.version;
                sort@SemVer(sortRequest)(sortedVersions);
                if (#sortedVersions.versions == 0) {
                    throw(ServiceFault, {
                        .type = FAULT_BAD_REQUEST,
                        .message = "Unable to resolve pacakge '" + name + 
                            "'. No version matches expression '" + 
                            currDependency.version + "'"
                    })
                };
                resolved << sortedVersions.versions[0];
                undef(allVersions)
            }
        }
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
        
        executionRequest.workingDirectory = global.path;
        executionRequest.args -> command;
        joinRequest.piece -> command;
        joinRequest.delimiter = " ";
        join@StringUtils(joinRequest)(prettyCommand);
        println@Console(prettyCommand)()
        //exec@Exec(executionRequest)()
    }]

    [installDependencies()() {
        DependencyTree;
        println@Console("Got dependency tree:")();
        value -> resolvedDependencies; DebugPrintValue
    }]
}
