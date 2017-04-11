include "packages.iol" from "packages"
include "semver.iol" from "semver"
include "utils.iol" from "jpm-utils"
include "db.iol" from "registry-database"
include "authorization.iol" from "authorization"

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
    .token: string
    .package: string
    .payload: raw
}

type WhoamiRequest: void {
    .token: string
}

type RegistryLogOutRequest: void {
    .token: string
}

type CreatePackageRequest: void {
    .token: string
    .name: string
}

type GetPackageRequest: string
type GetPackageResponse: void {
    .results[0, *]: PackageInformation
}

type GetPackageListRequest: void
type GetPackageListResponse: void {
    .results[0, *]: PackageInformation
}

type DownloadRequest: void {
    .packageIdentifier: string
    .version: SemVer
    .token?: string
}
type DownloadResponse: void {
    .payload: raw
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
    }

    .interfaceDependencies[0, *]: void {
        .name: string
        .version: string
    }
}

type TeamManagementRequest: void {
    .token: string
    .teamName: string
}

type TeamMemberManagementRequest: void {
    .token: string
    .teamName: string
    .username: string
}

type ChecksumRequest: void {
    .packageIdentifier: string
    .version: SemVer
    .token?: string
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

        publish(PublishRequest)(void)
            throws RegistryFault(ErrorMessage),

        createPackage(CreatePackageRequest)(void)
            throws RegistryFault(ErrorMessage),

        getPackageInfo(GetPackageRequest)(GetPackageResponse),

        getPackageList(GetPackageListRequest)(GetPackageListResponse),

        download(DownloadRequest)(DownloadResponse)
            throws RegistryFault(ErrorMessage),

        query(RegistryQueryRequest)(RegistryQueryResponse),

        getDependencies(RegDependencyRequest)(RegDependencyResponse),

        ping(string)(string),

        createTeam(TeamManagementRequest)(void)
            throws RegistryFault(ErrorMessage),

        deleteTeam(TeamManagementRequest)(void)
            throws RegistryFault(ErrorMessage),

        addTeamMember(TeamMemberManagementRequest)(void)
            throws RegistryFault(ErrorMessage),

        removeTeamMember(TeamMemberManagementRequest)(void)
            throws RegistryFault(ErrorMessage),

        promoteTeamMember(TeamMemberManagementRequest)(void)
            throws RegistryFault(ErrorMessage),

        demoteTeamMember(TeamMemberManagementRequest)(void)
            throws RegistryFault(ErrorMessage),

        listTeamMembers(TeamManagementRequest)(GroupMembersResponse)
            throws RegistryFault(ErrorMessage),

        checksum(ChecksumRequest)(string)
            throws RegistryFault(ErrorMessage)
}

