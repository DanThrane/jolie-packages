include "console.iol"
include "publish-iface.iol"

init {
    println@Console("publish-target: OK")()
}

execution { concurrent }

inputPort PublishTarget {
    Location: "local"
    Protocol: sodep
    Interfaces: IPublishTarget
}

main {
    [hello(name)(response) {
        response = "Hello, " + name + "!"
    }]
}
