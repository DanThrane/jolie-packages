include "utils.iol" from "jpm-utils"
include "registry.iol" from "registry"

type JPMAuthenticateRequest: void {
    .username: string
    .password: string
    .registry?: string
}

type JPMRegisterRequest: void {
    .username: string
    .password: string
    .registry?: string
}

type JPMLogoutRequest: void {
    .registry?: string
}

type JPMWhoamiRequest: void {
    .registry?: string
}

type JPMPingRequest: void {
    .registry?: string
}

type JPMInitializePackageRequest: void {
    .name: string
    .description: string
    .authors[0, *]: string
    .private: bool
}

type JPMQueryRequest: void {
    .query: string
}

type JPMPublishRequest: void {
    .registry?: string
}

type JPMQueryResponse: void {
    .registries[0, *]: void {
        .name: string
        .results[0, *]: PackageInformation
    }
}

type JPMStartRequest: void {
    .args[0, *]: string
    .config?: void {
        .profile: string
        .file: string
    }
    .debug?: void {
        .suspend: bool
        .port: int
    }
    .isVerbose: bool
    .trace: bool
    .check: bool
}

type JPMTeamManagementRequest: void {
    .teamName: string
    .registry: string
}

type JPMTeamMemberManagementRequest: void {
    .teamName: string
    .username: string
    .registry: string
}

type TransferRequest: void {
    .to: string
    .registry: string
}

interface IJPM {
    RequestResponse:
        setContext(string)(void)
            throws ServiceFault(ErrorMessage),

        setCallback(string)(void),

        authenticate(JPMAuthenticateRequest)(string)
            throws ServiceFault(ErrorMessage),

        register(JPMRegisterRequest)(string)
            throws ServiceFault(ErrorMessage),

        logout(JPMLogoutRequest)(void),

        whoami(JPMWhoamiRequest)(string)
            throws ServiceFault(ErrorMessage),

        initializePackage(JPMInitializePackageRequest)(void)
            throws ServiceFault(ErrorMessage),

        start(JPMStartRequest)(void)
            throws ServiceFault(ErrorMessage),

        installDependencies(void)(void)
            throws ServiceFault(ErrorMessage),

        query(JPMQueryRequest)(JPMQueryResponse)
            throws ServiceFault(ErrorMessage),

        publish(JPMPublishRequest)(void)
            throws ServiceFault(ErrorMessage),

        clearCache(void)(void),

        ping(JPMPingRequest)(void)
            throws ServiceFault(ErrorMessage),

        getPackage(void)(Package)
            throws ServiceFault(ErrorMessage),

        createTeam(JPMTeamManagementRequest)(void)
            throws ServiceFault(ErrorMessage),

        deleteTeam(JPMTeamManagementRequest)(void)
            throws ServiceFault(ErrorMessage),

        addTeamMember(JPMTeamMemberManagementRequest)(void)
            throws ServiceFault(ErrorMessage),

        removeTeamMember(JPMTeamMemberManagementRequest)(void)
            throws ServiceFault(ErrorMessage),

        promoteTeamMember(JPMTeamMemberManagementRequest)(void)
            throws ServiceFault(ErrorMessage),

        demoteTeamMember(JPMTeamMemberManagementRequest)(void)
            throws ServiceFault(ErrorMessage),

        listTeamMembers(JPMTeamManagementRequest)(GroupMembersResponse)
            throws ServiceFault(ErrorMessage),

        upgrade(void)(void)
            throws ServiceFault(ErrorMessage),

        dependencyTree(void)(undefined)
            throws ServiceFault(ErrorMessage),

        transfer(TransferRequest)(void)
            throws ServiceFault(ErrorMessage)
}

