include "admin.iol" from "registry"
include "console.iol"

parameters {
    KILL_TOKEN: string
}

outputPort Admin {
    Location: "socket://localhost:12346"
    Protocol: sodep
    Interfaces: IAdmin
}

main {
    kill@Admin(KILL_TOKEN)()
}
