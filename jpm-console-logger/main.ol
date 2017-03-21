include "jpm-log" "logger.iol"
include "console-ui" "console-ui.iol"

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

