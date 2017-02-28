init {
    global.helpText.("logout") = "
Logout from a registry.

Usage: jpm logout [--registry <NAME>]

If no registry is provided it will be set to 'public'.
";
    trim@StringUtils(global.helpText.("logout"))(global.helpText.("logout"));
    global.helpText.("logout").short = "Logout from a registry"
}

define HandleLogoutCommand {
    if (command == "logout") {
        handled = true;

        if (is_defined(command.options.("registry"))) {
            registryIdx = command.options.("registry");
            logoutRequest.registry = command.args[registryIdx + 1]
        };

        logout@JPM(logoutRequest)();
        println@Console("OK")()
    }
}

