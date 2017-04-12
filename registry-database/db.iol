include "packages.iol" from "packages"
include "utils.iol" from "jpm-utils"

type PackageInformation: void {
    .packageName: string
    .major: int
    .minor: int
    .patch: int
    .label?: string
    .description?: string
    .license: LicenseIdentifier
    .checksum: string
    .origin: string
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
    .origin?: string
}

type RegDBCheckIfPkgExistsResponse: bool

type RegDBPkgInfoRequest: void {
    .packageName: string
    .origin?: string
}

type RegDBPkgInfoResult: void {
    .results[0, *]: PackageInformation
}

type RegDBPkgInfoSpecific: void {
    .result[0, 1]: PackageInformation
}

type RegDBPkgListResult: void {
    .results[0, *]: PackageInformation
}

type RegDBCompareWithNewestRequest: void {
    .package: void {
        .name: string
        .version: SemVer
        .origin?: string
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
        .origin?: string
    }
}

type RegDBGetDependenciesResult: void {
    .dependencies[0, *]: void {
        .name: string
        .version: string
        .origin?: string // TODO Should not be optional
    }
    .interfaceDependencies[0, *]: void {
        .name: string
        .version: string
        .origin?: string // TODO Should not be optional
    }
}

type PackageInsertionRequest: void {
    .package: Package
    .checksum: string
    .origin?: string
}

type RegDBPkgInfoSpecificRequest: void {
    .packageName: string
    .version: SemVer
    .origin?: string
}

type RegDBCreatePackage: string {
    .origin?: string
}

interface IRegistryDatabase {
    RequestResponse:
        query
            (RegDBQueryRequest)
            (RegDBQueryResult),

        checkIfPackageExists
            (RegDBCheckIfPkgExistsRequest)
            (RegDBCheckIfPkgExistsResponse),

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

        createPackage(RegDBCreatePackage)(void)
            throws RegDBFault(ErrorMessage),

        getDependencies
            (RegDBGetDependenciesRequest)
            (RegDBGetDependenciesResult)
            throws RegDBFault(ErrorMessage)
}

