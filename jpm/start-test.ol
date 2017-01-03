include "jpm.iol"
include "string_utils.iol"
include "console.iol"

outputPort JPM {
    Location: "socket://localhost:3333"
    Protocol: sodep
    Interfaces: IJPM
}

main
{
    scope(s) {
        install(ServiceFault =>
            println@Console("JPM threw a service fault!")();
            println@Console("Type: " + s.ServiceFault.type)();
            println@Console("Message: " + s.ServiceFault.message)();
            if (is_defined(s.ServiceFault.details)) {
                valueToPrettyString@StringUtils(s.ServiceFault.details)(prettyDetails);
                println@Console("Details: " + prettyDetails)()
            }
        );
        setContext@JPM(".")();
        start@JPM()()
    }
}