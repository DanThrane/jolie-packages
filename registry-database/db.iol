include "packages" "packages.iol"
include "jpm-utils" "utils.iol"

type PackageInformation: void {
    .packageName: string
    .major: int
    .minor: int
    .patch: int
    .label?: string
    .description?: string
    .license: LicenseIdentifier
    .checksum: string
}

type RegDBQueryRequest: void {
    .query: string
}

type RegDBQueryResult: void {
    .results[0, *]: PackageInformation
}

type RegDBCheckIfPkgExistsRequest: void {
    .packageName: string
    .version?: SemVer
}

type RegDBPkgInfoRequest: void {
    .packageName: string
}

type RegDBPkgInfoResult: void {
    .results[0, *]: PackageInformation
}

type RegDBPkgInfoSpecific: void {
    .result: PackageInformation
}

type RegDBPkgListResult: void {
    .results[0, *]: PackageInformation
}

type RegDBCompareWithNewestRequest: void {
    .package: void {
        .name: string
        .version: SemVer
    }
}

type RegDBCompareWithNewestResult: void {
    .isNewest: bool
    .newestVersion: SemVer
}

type RegDBGetDependenciesRequest: void {
    .package: void {
        .name: string
        .version: SemVer
    }
}

type RegDBGetDependenciesResult: void {
    .dependencies[0, *]: void {
        .name: string
        .version: string
    }
    .interfaceDependencies[0, *]: void {
        .name: string
        .version: string
    }
}

type PackageInsertionRequest: void {
    .package: Package
    .checksum: string
}

type RegDBPkgInfoSpecificRequest: void {
    .packageName: string
    .version: SemVer
}

interface IRegistryDatabase {
    RequestResponse:
        query
            (RegDBQueryRequest)
            (RegDBQueryResult),

        checkIfPackageExists
            (RegDBCheckIfPkgExistsRequest)
            (bool),

        getInformationAboutPackage
            (RegDBPkgInfoRequest)
            (RegDBPkgInfoResult),

        getInformationAboutPackageOfVersion
            (RegDBPkgInfoSpecificRequest)
            (RegDBPkgInfoSpecific)
            throws RegDBFault(ErrorMessage),

        getPackageList(void)(RegDBPkgListResult),

        comparePackageWithNewestVersion
            (RegDBCompareWithNewestRequest)
            (RegDBCompareWithNewestResult),

        insertNewPackage(PackageInsertionRequest)(void)
            throws RegDBFault(ErrorMessage),

        createPackage(string)(void)
            throws RegDBFault(ErrorMessage),

        getDependencies
            (RegDBGetDependenciesRequest)
            (RegDBGetDependenciesResult)
            throws RegDBFault(ErrorMessage)
}

