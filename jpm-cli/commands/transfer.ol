init {
    global.helpText.("transfer") = "
Command for transfering ownership of a package.

Usage: jpm transfer [--registry <REG-NAME>] <team-name>

<REG-NAME> defaults to 'public' if not provided.

This command will transfer the ownership of the package entirely to the
team named in the command. If you are not a member of this team, then you will
no longer be able to work with this package on the registry.

You will be prompted to re-authenticate before this action can be completed.
    ";

    trim@StringUtils
        (global.helpText.("transfer"))
        (global.helpText.("transfer"));

    global.helpText.("transfer").short = "Transfer ownership of this package"
}

define HandleTransferCommand {
    if (command == "transfer") {
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

        if (#command.args != 1) {
            throw(CLIFault, {
                .type = 400,
                .message = "Usage: jpm transfer [--registry <REG-NAME>] " +
                    "<team-name>"
            })
        } else {
            displayPrompt@ConsoleUI("Username")
                (authenticationRequest.username);

            displayPasswordPrompt@ConsoleUI("Password")
                (authenticationRequest.password);

            authenticate@JPM(authenticationRequest)();

            transferRequest.to = command.args[0];
            transferRequest.registry = registry;
            transfer@JPM(transferRequest)()
        }
    }
}

