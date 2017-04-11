include "admin.iol" from "registry"
include "console.iol"

init {
    KILL_TOKEN -> global.params.KILL_TOKEN
}

outputPort Admin {
    Location: "socket://localhost:12346"
    Protocol: sodep
    Interfaces: IAdmin
}

main {
    kill@Admin(KILL_TOKEN)()
}
