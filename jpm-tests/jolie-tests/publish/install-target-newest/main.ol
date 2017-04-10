include "publish-iface.iol" from "publish-target"
include "console.iol"

outputPort PublishTarget {
    Interfaces: IPublishTarget
}

embedded {
    JoliePackage:
        "publish-target" in PublishTarget
}

main {
    hello@PublishTarget("Dan")(greeting);
    println@Console(greeting)()
}
