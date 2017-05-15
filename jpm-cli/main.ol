include "console.iol"
include "runtime.iol"

include "jpm.iol" from "jpm"
include "callback.iol" from "jpm"
include "utils.iol" from "jpm-utils"
include "semver.iol" from "semver"
include "console_ui.iol" from "console-ui"

include "argument-parser.iol"

#ext outputPort JPM {
    Interfaces: IJPM
}

outputPort ArgumentParser {
    Interfaces: IArgumentParser
}

outputPort CallbackServer {
    Interfaces: IJPMCallback
    Protocol: sodep
    Interfaces: IJPMCallback
}

embedded {
    Jolie:
        "argument-parser.ol" in ArgumentParser,
        "callback-server.ol" in CallbackServer
}

// This needs to go after definitions used by commands
include "commands/all.ol"

main {
    install(IOException =>
        valueToPrettyString@StringUtils(main.IOException)(prettyEx);
        println@Console(prettyEx)()
    );
    install(ServiceFault =>
        errorMessage = "Error! ";
        errorMessage += main.ServiceFault.type;
        errorMessage += " ";
        if (main.ServiceFault.type == FAULT_BAD_REQUEST) {
            errorMessage += "(Bad request)"
        } else if (main.ServiceFault.type == FAULT_INTERNAL) {
            errorMessage += "(Internal)"
        };
        errorMessage += "\n";
        errorMessage += main.ServiceFault.message;
        if (is_defined(main.ServiceFault.details)) {
            valueToPrettyString@StringUtils(main.ServiceFault.details)
                (prettyDetails);
            errorMessage += "\nAdditional details:\n";
            errorMessage += prettyDetails
        };
        println@Console(errorMessage)()
    );

    install(CLIFault =>
        errorMessage = "Error [CLI]! ";
        errorMessage += main.CLIFault.type;
        errorMessage += " ";
        if (main.CLIFault.type == FAULT_BAD_REQUEST) {
            errorMessage += "(Bad request)"
        } else if (main.CLIFault.type == FAULT_INTERNAL) {
            errorMessage += "(Internal)"
        };
        errorMessage += "\n";
        errorMessage += main.CLIFault.message;
        println@Console(errorMessage)()
    );

    context = args[0];
    setContext@JPM(context)();
    setCallback@JPM(CALLBACK_LOCATION)();

    // Parse arguments
    if (#args == 1) {
        args[1] = "help"
    };

    parseRequest.args -> args;
    parseRequest.begin = 2;
    parse@ArgumentParser(parseRequest)(command);
    command = args[1];

    HandleCommand
}

