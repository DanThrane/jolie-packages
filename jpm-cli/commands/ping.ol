init {
    global.helpText.("ping") = "
Ping a registry.

Usage: jpm ping [--registry <NAME>]

If no registry is given it will be set to 'public'.
";
    trim@StringUtils(global.helpText.("ping"))(global.helpText.("ping"));
    global.helpText.("ping").short = "Ping dependencies"
}

define HandlePingCommand {
    if (command == "ping") {
        handled = true;

        ping@JPM()();
        println@Console("OK")()
    }
}

