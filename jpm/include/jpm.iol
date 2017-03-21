include "jpm-utils" "utils.iol"
include "registry" "registry.iol"

type JPMAuthenticationRequest: void {
    .username: string
    .password: string
    .registry?: string
}

type JPMRegistrationRequest: void {
    .username: string
    .password: string
    .registry?: string
}

type LogoutRequest: void {
    .registry?: string
}

type JPMWhoamiRequest: void {
    .registry?: string
}

type InitializationRequest: void {
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
    .deployment?: void {
        .profile: string
        .file: string
    }
    .debug?: void {
        .suspend: bool
        .port: int
    }
    .isVerbose: bool 
}

interface IJPM {
    RequestResponse:
        setContext(string)(void) throws ServiceFault(ErrorMessage),
        authenticate(JPMAuthenticationRequest)(string)
            throws ServiceFault(ErrorMessage),
        register(JPMRegistrationRequest)(string)
            throws ServiceFault(ErrorMessage),
        logout(LogoutRequest)(void),
        whoami(JPMWhoamiRequest)(string)
            throws ServiceFault(ErrorMessage),
        initializePackage(InitializationRequest)(void) 
            throws ServiceFault(ErrorMessage),
        start(JPMStartRequest)(void) throws ServiceFault(ErrorMessage),
        installDependencies(void)(void) 
            throws ServiceFault(ErrorMessage),
        query(JPMQueryRequest)(JPMQueryResponse) 
            throws ServiceFault(ErrorMessage),
        publish(JPMPublishRequest)(void) throws ServiceFault(ErrorMessage),
        clearCache(void)(void),
        ping(string)(void) throws ServiceFault(ErrorMessage),
        pkgInfo(void)(Package) throws ServiceFault(ErrorMessage)
}
