include "jpm-utils" "utils.iol"
include "registry" "registry.iol"

type InitializationRequest: void {
    .name: string
    .description: string
    .authors[0, *]: string
    .baseDirectory: string
}

type JPMQueryRequest: void {
    .query: string
}

type JPMQueryResponse: void {
    .registries[0, *]: void {
        .name: string
        .results[0, *]: PackageInformation
    }
}

interface IJPM {
    RequestResponse:
        setContext(string)(void) throws ServiceFault(ErrorMessage),
        initializePackage(InitializationRequest)(void) 
            throws ServiceFault(ErrorMessage),
        start(void)(void) throws ServiceFault(ErrorMessage),
        installDependencies(void)(void) throws ServiceFault(ErrorMessage),
        query(JPMQueryRequest)(JPMQueryResponse) throws ServiceFault(ErrorMessage)
}
