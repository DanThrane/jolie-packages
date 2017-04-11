include "publish-iface.iol" from "publish-target"
include "console.iol"

outputPort PublishTarget {
    Interfaces: IPublishTarget
}

embedded {
    Jolie:
        "publish-target.pkg" in PublishTarget
}

main {
    hello@PublishTarget("Dan")(greeting);
    println@Console(greeting)()
}
