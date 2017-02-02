include "registry" "admin.iol"

outputPort Admin {
    Location: "socket://localhost:12346"
    Protocol: sodep
    Interfaces: IAdmin
}

main {
    kill@Admin("1234")()
}
