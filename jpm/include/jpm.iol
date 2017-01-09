include "jpm-utils" "utils.iol"

type InitializationRequest: void {
    .name: string
    .description: string
    .authors[0, *]: string
    .baseDirectory: string
}

interface IJPM {
    RequestResponse:
        setContext(string)(void) throws ServiceFault(ErrorMessage),
        initializePackage(InitializationRequest)(void) 
            throws ServiceFault(ErrorMessage),
        start(void)(void) throws ServiceFault(ErrorMessage),
        installDependencies(void)(void) throws ServiceFault(ErrorMessage)
}
