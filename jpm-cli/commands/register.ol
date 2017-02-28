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

        with (consumeRequest) {
            .parsed << command;
            .options.registry.count = 1
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);

        registry -> command.options.registry;
        if (!is_defined(registry)) registry = "public";

        registrationRequest.registry = registry;

        if (#command.args == 2) {
            registrationRequest.username = command.args[0];
            registrationRequest.password = command.args[1]
        } else if (#command.args == 0) {
            displayPrompt@ConsoleUI("Username")(registrationRequest.username);
            displayPasswordPrompt@ConsoleUI("Password")
                (registrationRequest.password);
            displayPasswordPrompt@ConsoleUI("Password (Repeat)")(repeat);
            if (registrationRequest.password != repeat) {
                throw(CLIFault, {
                    .type = 400,
                    .message = "Passwords do not match"
                })
            }
        } else {
            throw(CLIFault, {
                .type = 400,
                .message = "Must pass both username and password!"
            })
        };

        register@JPM(registrationRequest)(token);
        println@Console(token)()
    }
}

