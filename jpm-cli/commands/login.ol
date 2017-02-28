init {
    global.helpText.("login") = "
Login to a given registry.

Usage: jpm login [--registry <NAME>] [<USERNAME> <PASSWORD>]

By default the registry name will be set to 'public'. A login prompt is shown
if no username or password is provided.
";
    trim@StringUtils(global.helpText.("login"))(global.helpText.("login"));
    global.helpText.("login").short = "Login to a given registry."
}

define HandleLoginCommand {
    if (command == "login") {
        handled = true;

        with (consumeRequest) {
            .parsed << command;
            .options.registry.count = 1
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);

        registry -> command.options.registry;
        if (!is_defined(registry)) registry = "public";

        authenticationRequest.registry = registry;

        if (#command.args == 2) {
            authenticationRequest.username = command.args[0];
            authenticationRequest.password = command.args[1]
        } else if (#command.args == 0) {
            displayPrompt@ConsoleUI("Username")
                (authenticationRequest.username);
            displayPasswordPrompt@ConsoleUI("Password")
                (authenticationRequest.password)
        } else {
            throw(CLIFault, {
                .type = 400,
                .message = "Must pass both username and password"
            })
        };

        authenticate@JPM(authenticationRequest)()
    }
}

