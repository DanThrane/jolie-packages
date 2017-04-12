include "downloader.iol"
include "registry.iol" from "registry"
include "console.iol"
include "string_utils.iol"
include "file.iol"
include "zip_utils.iol"
include "system.iol" from "system-java"

execution { sequential }

outputPort Registry {
    Protocol: sodep
    Interfaces: IRegistry
}

inputPort Downloader {
    Location: "local"
    Interfaces: IDownloader
}

init {
    install(DownloaderFault => nullProcess);
    getFileSeparator@File()(FILE_SEP);
    getUserHomeDirectory@System()(PATH_HOME);
    PATH_CACHE = PATH_HOME + FILE_SEP + ".jpm_cache";
    PATH_KNOWN_REGISTRIES = PATH_CACHE + FILE_SEP + "registries.json";

    exists@File(PATH_CACHE)(cacheExists);
    if (!cacheExists) {
        mkdir@File(PATH_CACHE)()
    };

    exists@File(PATH_KNOWN_REGISTRIES)(hasKnownRegistries);
    if (hasKnownRegistries) {
        readFile@File({
            .filename = PATH_KNOWN_REGISTRIES,
            .format = "json"
        })(knownRegistries)
    }
}

/**
 * @input registryLocation: string
 * @output registryIndex: int
 */
define CacheRegistryIndex {
    _i = i;
    found = false;
    for (i = 0, i < #knownRegistries.registries && !found, i++) {
        if (knownRegistries.registries[i] == registryLocation) {
            registryIndex = i;
            found = true
        }
    };
    i = _i;
    undef(_i);

    if (!found) {
        registryIndex = #knownRegistries.registries;
        knownRegistries.registries[registryIndex] = registryLocation;
        with (writeFileRequest) {
            .content << knownRegistries;
            .filename = PATH_KNOWN_REGISTRIES;
            .format = "json"
        };
        writeFile@File(writeFileRequest)();
        undef(writeFileRequest)
    }
}

/**
 * @input request: InstallRequest
 * @output cacheInstallationLocation: string
 * @output installationName: string
 */
define CacheLocation {
    registryLocation = request.registryLocation;
    CacheRegistryIndex;
    registryFolder = PATH_CACHE + FILE_SEP + registryIndex;
    exists@File(registryFolder)(registryFolderExists);
    if (!registryFolderExists) {
        mkdir@File(registryFolder)()
    };
    installationName = request.name + "_" +
        request.major + "_" + request.minor + "_" + request.patch + ".pkg";
    cacheInstallationLocation = registryFolder + FILE_SEP + installationName
}

main {
    [installDependency(request)() {
        CacheLocation;
        exists@File(cacheInstallationLocation)(hasCachedCopy);

        if (!hasCachedCopy) {
            Registry.location = request.registryLocation;

            scope(pkgScope) {
                install(InvalidArgumentFault =>
                    println@Console(InvalidArgumentFault.message)()
                );
                install(RegistryFault =>
                    throw(DownloaderFault, pkgScope.RegistryFault)
                );

                downloadRequest.packageIdentifier = request.name;
                downloadRequest.version.major = request.major;
                downloadRequest.version.minor = request.minor;
                downloadRequest.version.patch = request.patch;
                if (is_defined(request.token)) {
                    downloadRequest.token = request.token
                };

                download@Registry(downloadRequest)(value);
                writeFile@File({
                    .content = value.payload,
                    .filename = cacheInstallationLocation
                })()
            }
        };

        packagesLocation = request.targetPackage + FILE_SEP + "jpm_packages";
        installationLocation = packagesLocation + FILE_SEP + request.name;

        exists@File(packagesLocation)(hasPackagesFolder);
        if (!hasPackagesFolder) mkdir@File(packagesLocation)();

        unzip@ZipUtils({
            .targetPath = installationLocation,
            .filename = cacheInstallationLocation
        })()
    }]

    [clearCache()() {
        exists@File(PATH_CACHE)(cacheExists);
        if (cacheExists) {
            deleteDir@File(PATH_CACHE)()
        };
        mkdir@File(PATH_CACHE)()
    }]
}

