include "console.iol"
include "jpm" "jpm.iol"
include "jpm-utils" "utils.iol"
include "tables" "tables.iol"
include "semver" "semver.iol"

outputPort JPM {
    Interfaces: IJPM
}

embedded {
    JoliePackage:
        "jpm" in JPM {} // TODO FIXME bug in interpreter. Cfg should be optional
}

define QueryTest {
    query@JPM({ .query = "package" })(results);
    value -> results; DebugPrintValue
}

define DependencyTreeTest {
    setContext@JPM("/home/dan/projects/jolie-packages/data/test")();
    installDependencies@JPM()()
}

main {
    install(ServiceFault =>
        println@Console("An error has occoured!")();
        value -> main.ServiceFault; DebugPrintValue
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
")()
    } else if (command == "init") {
        nullProcess
    } else if (command == "install") {
        installDependencies@JPM()()
    } else if (command == "publish") {
        nullProcess
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
        start@JPM()()
    } else if (command == "login") {
        if (#args < 4) {
            // TODO Should read from console
            println@Console("Usage: jpm login <username> <password> [registry]")()
        } else {
            authenticationRequest.username = args[2];
            authenticationRequest.password = args[3];
            if (#args == 5) {
                authenticationRequest.registry = args[4]
            };
            value -> authenticationRequest; DebugPrintValue;
            authenticate@JPM(authenticationRequest)(token);
            println@Console(token)()
        }
    } else if (command == "register") {
        if (#args < 4) {
            println@Console("Usage: jpm register <username> <password> [registry]")()
        } else {
            registrationRequest.username = args[2];
            registrationRequest.password = args[3];
            if (#args == 5) {
                registrationRequest.registry = args[4]
            };
            register@JPM(registrationRequest)(token);
            println@Console(token)()
        }
    } else if (command == "logout") {
        logoutRequest.token = "5f0433e5-d4b0-4080-8d52-73841e8a9caf";
        if (#args == 3) {
            logoutRequest.registry = args[2]
        };
        logout@JPM(logoutRequest)()
    } else if (command == "whoami") {
        whoami@JPM({ .token = "f0e003e3-4405-410f-b416-ff07d619dd3e" })(res);
        println@Console(res)()
    }
    else {
        println@Console("Unknown command '" + command + "'")()
    }
}
