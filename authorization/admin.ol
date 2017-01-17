include "authorization.iol"

outputPort Authorization {
    Location: "socket://localhost:44444"
    Protocol: sodep
    Interfaces: IAuthorization
}

main {
    debug@Authorization()()
}
