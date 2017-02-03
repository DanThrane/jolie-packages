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
            valueToPrettyString@StringUtils(main.ServiceFault.details)(prettyDetails);
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
    command -> args[1];
    if (#args <= 1 || command == "help") {
        println@Console("JPM - The Jolie Package Manager
Version 0.1.0

Usage: jpm <command> <arguments>

Available commands:
-------------------

  - init            Initializes a package in the current directory
  - install         Installs the dependencies, which are located in package.json
  - status          Prints out JPM's knowledge of the package placed in the 
                    current directory
  - publish         Publishes the package in the current directory to the 
                    central repository.
  - search <q>      Searches the local database for a given package
  - help            This command
  - start <args>    Starts this package
  - cache <cmd>     Cache sub command
")()
    } else if (command == "init") {
        displayPrompt@ConsoleUI("Package name")(req.name);
        displayPrompt@ConsoleUI("Package description")(req.description);
        displayPrompt@ConsoleUI("Author: [Format: name <email> (homepage)]")(req.authors);
        displayYesNoPrompt@ConsoleUI("Private package?" { 
            .defaultValue = true 
        })(req.private);
        initializePackage@JPM(req)()
    } else if (command == "install") {
        installDependencies@JPM()()
    } else if (command == "publish") {
        publish@JPM()()
    } else if (command == "search") {
        query -> args[2];
        query@JPM({ .query = query })(results);
        foreach (repository : results) {
            println@Console("In repository: " + repository)();
            println@Console("--------------------------------")();
            tablesRequest.values -> results.(repository).results;
            
            currentValue -> tablesRequest.values[i];
            for (i = 0, i < #tablesRequest.values, i++) {
                version << {
                    .major = currentValue.major,
                    .minor = currentValue.minor,
                    .patch = currentValue.patch,
                    .label = currentValue.label
                };
                convertToString@SemVer(version)(versionString);
                currentValue.version = versionString;
                undef(currentValue.major);
                undef(currentValue.minor);
                undef(currentValue.patch);
                undef(currentValue.label)
            };

            toTextTable@Tables(tablesRequest)(table);
            println@Console(table)()
        }
    } else if (command == "start") {
        isDeploying = args[2] == "--deploy";
        if (isDeploying) {
            startReq.deployment.profile = args[3];
            startReq.deployment.file = args[4]
        };

        i = 2;
        if (isDeploying) i = 5;
        for (i = i, i < #args, i++) {
            startReq.args[#startReq.args] = args[i]
        };

        start@JPM(startReq)()
    } else if (command == "login") {
        if (#args >= 4) {
            authenticationRequest.username = args[2];
            authenticationRequest.password = args[3];
            if (#args == 5) {
                authenticationRequest.registry = args[4]
            }
        } else {
            displayPrompt@ConsoleUI("Username")
                (authenticationRequest.username);
            displayPasswordPrompt@ConsoleUI("Password")
                (authenticationRequest.password);
            if (#args == 3) {
                authenticationRequest.registry = args[2]
            }
        };
        authenticate@JPM(authenticationRequest)(token);
        println@Console("OK")()
    } else if (command == "register") {
        if (#args >= 4) {
            registrationRequest.username = args[2];
            registrationRequest.password = args[3];
            if (#args == 5) {
                registrationRequest.registry = args[4]
            }
        } else {
            displayPrompt@ConsoleUI("Username")(registrationRequest.username);
            displayPasswordPrompt@ConsoleUI("Password")
                (registrationRequest.password);
            displayPasswordPrompt@ConsoleUI("Password (Repeat)")(repeat);
            if (registrationRequest.password != repeat) {
                throw(CLIFault, {
                    .type = 400,
                    .message = "Passwords do not match"
                })
            };

            if (#args == 3) {
                registrationRequest.registry = args[2]
            }
        };
        register@JPM(registrationRequest)(token);
        println@Console(token)()
    } else if (command == "logout") {
        if (#args == 3) {
            logoutRequest.registry = args[2]
        };
        logout@JPM(logoutRequest)();
        println@Console("OK")()
    } else if (command == "whoami") {
        whoami@JPM()(res);
        println@Console(res)()
    } else if (command == "cache") {
        subCommand -> args[2];
        if (subCommand == "clear") {
            clearCache@JPM()()
        } else {
            println@Console("Unknown subcommand '" + subCommand + "'")()
        }
    } else if (command == "ping") {
        ping@JPM()();
        println@Console("OK")()
    }
    else {
        println@Console("Unknown command '" + command + "'")()
    }
}
