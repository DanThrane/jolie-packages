include "console.iol"
include "runtime.iol"

include "jpm" "jpm.iol"
include "jpm-utils" "utils.iol"
include "tables" "tables.iol"
include "semver" "semver.iol"
include "console-ui" "console_ui.iol"

outputPort JPM {
    Interfaces: IJPM
}

embedded {
    JoliePackage:
        "jpm" in JPM
}

// This needs to go after definitions used by commands
include "commands/all.ol"

main {
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

    setContext@JPM(args[0])();

    // Parse arguments
    command = args[1];
    for (i = 2, i < #args, i++) {
        startsWith@StringUtils(args[i] { .prefix = "--" })(isOption);

        if (isOption) {
            length@StringUtils(args[i])(optionLength);
            substring@StringUtils(args[i] { .begin = 2, .end = optionLength })
                (optionName);
            command.options.(optionName) = i - 2
        };

        command.args[i - 2] = args[i]
    };

    HandleCommand
}

