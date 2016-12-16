include "registry.iol"
include "console.iol"
include "file.iol"

execution { concurrent }

inputPort Registry {
    Location: "socket://localhost:12345"
    Protocol: sodep
    Interfaces: IRegistry
}

define checkIfPackageExists {
    packageExists = is_defined(global.packages.(packageName))
}

define createPackage {
    global.packages.(packageName) << { .name = packageName };
    global.packageList[#global.packageList] = packageName
}

define getPackageInformation {
    packageInformation -> global.packages.(packageName)
}

main
{
    [authenticate(req)(res) {
        res = true;
        res.token = new
    }]

    [createPackage(req)(res) {
        packageName = req.name;
        checkIfPackageExists;

        if (packageExists) {
            res = false;
            res.message = "Package already exists!"
        } else {
            createPackage;
            res = true;
            res.message = "Package created!"
        }
    }]

    [getPackageList(req)(res) {
        results -> res.results;
        for (i = 0, i < #global.packageList, i++) {
            results[#results] << { .name = global.packageList[i] }
        }
    }]

    [getPackageInfo(packageName)(res) {
        checkIfPackageExists;

        if (packageExists) {
            getPackageInformation;
            res.package -> packageInformation
        }
    }]

    [publish(req)(res) {
        packageName = req.package;
        checkIfPackageExists;

        if (packageExists) {
            writeFile@File({ 
                .content = req.payload,
                .filename = packageName
            })();
            res = true;
            res.message = "Package published!"
        } else {
            res = false;
            res.message = "Package not found!"
        }
    }]
}
