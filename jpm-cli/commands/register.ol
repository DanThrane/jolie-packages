init {
    global.helpText.("register") = "
Create a new user with a registry.

Usage: jpm register [--registry <NAME>] [<USERNAME> <PASSWORD>]

If no registry is given it will be set to 'public'. If no username and password
is provided a login prompt will be shown.
";
    trim@StringUtils(global.helpText.("register"))(global.helpText.("register"));
    global.helpText.("register").short = "Create a new user with a registry"
}

define HandleRegisterCommand {
    if (command == "register") {
        handled = true;

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
    }
}

