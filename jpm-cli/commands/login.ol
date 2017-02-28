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

        // TODO Use new arguments
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
        }
    }
}

