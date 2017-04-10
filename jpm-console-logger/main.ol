include "logger.iol" from "jpm-log"
include "console-ui.iol" from "console-ui"

ext inputPort ConsoleLogger {
    Interfaces: ILogger
}

execution { concurrent }

main {
    [info(message)] {

    }

    [warning(message)] {

    }

    [error(message)] {

    }

    [createProgres()() {

    }]

    [destroyProgress()() {

    }]
}

