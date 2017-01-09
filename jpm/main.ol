include "jpm.iol"
include "file.iol"
include "json_utils.iol"
include "string_utils.iol"
include "console.iol"
include "packages" "packages.iol"

execution { sequential }

constants
{
    FOLDER_PACKAGES = "jpm_packages"
}

inputPort JPM {
    Location: "socket://localhost:3333"
    Protocol: sodep
    Interfaces: IJPM
}

outputPort Packages {
    Location: "socket://localhost:8888"
    Protocol: sodep
    Interfaces: IPackages
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
        nullProcess
    }]
}
