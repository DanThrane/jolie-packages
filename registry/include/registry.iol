// Utility types
type ServiceMessage: bool {
    .message: string
}

type PackageManifest: void {
    .name: string
    .description: string
    .license: string
    .authors[1, *]: string
    .version: string
}

type PackageInformation: void {
    .name: string
    .manifests[0, *]: PackageManifest
}

// Request response types

type AuthenticationRequest: void {
    .username: string
    .password: string
}

type AuthenticationResponse: bool {
    .token: string
}

type RegistrationRequest: void {
    .username: string
    .password: string
}
type RegistrationResponse: ServiceMessage

type PublishRequest: void {
    .package: string
    .payload: raw
}

type PublishResponse: ServiceMessage

type CreatePackageRequest: void {
    .token: string
    .name: string
}

type CreatePackageResponse: ServiceMessage

type GetPackageRequest: string
type GetPackageResponse: void {
    .package?: PackageInformation
}

type GetPackageListRequest: void {
    .query?: string
}
type GetPackageListResponse: void {
    .results[0, *]: PackageInformation
}

type DownloadRequest: void {
    .packageIdentifier: string
}
type DownloadResponse: bool {
    .message: string
    .payload?: raw
}

interface IRegistry {
    RequestResponse:
        authenticate(AuthenticationRequest)(AuthenticationResponse),
        register(RegistrationRequest)(RegistrationResponse),
        publish(PublishRequest)(PublishResponse),
        createPackage(CreatePackageRequest)(CreatePackageResponse),
        getPackageInfo(GetPackageRequest)(GetPackageResponse),
        getPackageList(GetPackageListRequest)(GetPackageListResponse),
        download(DownloadRequest)(DownloadResponse),
        logout(void)(void)
}
