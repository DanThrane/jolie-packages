include "jpm" "callback.iol"
include "console.iol"
include "string_utils.iol"
include "console-ui" "console_ui.iol"

execution { sequential }

inputPort CallbackPort {
    Location: CALLBACK_LOCATION
    Protocol: sodep
    Interfaces: IJPMCallback
}

main {
    [jpmEvent(event)] {
        if (event.type == "download-begin") {
            printfc@ConsoleUI("@|bold,green [INFO]|@ Downloading package %s@%d.%d.%d" {
                .args[0] = event.data.name,
                .args[1] = event.data.info.version.major,
                .args[2] = event.data.info.version.minor,
                .args[3] = event.data.info.version.patch
            })();
            displaySpinner@ConsoleUI()()
        } else if (event.type == "download-end") {
            stopSpinner@ConsoleUI()();
            printfc@ConsoleUI("@|bold,green [INFO]|@ Downloading finished %s@%d.%d.%d" {
                .args[0] = event.data.name,
                .args[1] = event.data.info.version.major,
                .args[2] = event.data.info.version.minor,
                .args[3] = event.data.info.version.patch
            })()
        }
    }
}

