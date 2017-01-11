include "packages" "packages.iol"
include "semver" "semver.iol"
include "jpm-utils" "utils.iol"

// Utility types
type ServiceMessage: bool {
    .message: string
}

type PackageInformation: void {
    .packageName: string
    .major: int
    .minor: int
    .patch: int
    .label?: string
    .description?: string
    .license: LicenseIdentifier
}

// Request response types

type AuthenticationRequest: void {
    .username: string
    .password: string
}

type AuthenticationResponse: string

type RegistrationRequest: void {
    .username: string
    .password: string
}
type RegistrationResponse: string

type PublishRequest: void {
    .package: string
    .payload: raw
}

type WhoamiRequest: void {
    .token: string
}

type RegistryLogOutRequest: void {
    .token: string
}

type PublishResponse: ServiceMessage

type CreatePackageRequest: void {
    .token: string
    .name: string
}

type CreatePackageResponse: ServiceMessage

type GetPackageRequest: string
type GetPackageResponse: void {
    .packages[0, *]: PackageInformation
}

type GetPackageListRequest: void
type GetPackageListResponse: void {
    .results[0, *]: PackageInformation
}

type DownloadRequest: void {
    .packageIdentifier: string
    .version: SemVer
}
type DownloadResponse: bool {
    .message: string
    .payload?: raw
}

type RegistryQueryRequest: void {
    .query: string
}
type RegistryQueryResponse: void {
    .results[0, *]: PackageInformation
}

type RegDependencyRequest: void {
    .packageName: string
    .version: SemVer
}
type RegDependencyResponse: void {
    .dependencies[0, *]: void {
        .name: string
        .version: string
        .type: int
    }
}

interface IRegistry {
    RequestResponse:
        authenticate(AuthenticationRequest)(AuthenticationResponse)
            throws RegistryFault(ErrorMessage),
        register(RegistrationRequest)(RegistrationResponse)
            throws RegistryFault(ErrorMessage),
        whoami(WhoamiRequest)(string)
            throws RegistryFault(ErrorMessage),
        logout(RegistryLogOutRequest)(void),
        publish(PublishRequest)(PublishResponse),
        createPackage(CreatePackageRequest)(CreatePackageResponse),
        getPackageInfo(GetPackageRequest)(GetPackageResponse),
        getPackageList(GetPackageListRequest)(GetPackageListResponse),
        download(DownloadRequest)(DownloadResponse),
        query(RegistryQueryRequest)(RegistryQueryResponse),
        getDependencies(RegDependencyRequest)(RegDependencyResponse)
}
