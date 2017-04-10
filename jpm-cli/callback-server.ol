include "callback.iol" from "jpm"
include "console.iol"
include "string_utils.iol"
include "console_ui.iol" from "console-ui"

execution { sequential }

inputPort CallbackPort {
    Location: CALLBACK_LOCATION
    Protocol: sodep
    Interfaces: IJPMCallback
}

main {
    [jpmEvent(event)] {
        if (event.type == "download-begin") {
            printfc@ConsoleUI("@|bold ⬇️️|@ %-20s %s@%d.%d.%d" {
                .args[0] = "Downloading",
                .args[1] = event.data.name,
                .args[2] = event.data.info.version.major,
                .args[3] = event.data.info.version.minor,
                .args[4] = event.data.info.version.patch
            })();
            displaySpinner@ConsoleUI()()
        } else if (event.type == "download-end") {
            stopSpinner@ConsoleUI()();
            printfc@ConsoleUI("@|bold,green ✔️|@ %-20s %s@%d.%d.%d" {
                .args[0] = "Completed",
                .args[1] = event.data.name,
                .args[2] = event.data.info.version.major,
                .args[3] = event.data.info.version.minor,
                .args[4] = event.data.info.version.patch
            })()
        } else if (event.type == "info") {
            printfc@ConsoleUI("@|bold,cyan [INFO]|@ %s" {
                .args[0] = event.data
            })()
        }
    }
}

