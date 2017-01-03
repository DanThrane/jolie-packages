constants
{
    FAULT_BAD_REQUEST = 400,
    FAULT_INTERNAL = 500
}

type ErrorMessage: void {
    .type: int
    .message: string
    .details?: undefined
}

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
        start(void)(void) throws ServiceFault(ErrorMessage)
}
