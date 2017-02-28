init {
    global.helpText.("ping") = "
Ping a registry.

Usage: jpm ping [--registry <NAME>]

If no registry is given it will be set to 'public'.
";
    trim@StringUtils(global.helpText.("ping"))(global.helpText.("ping"));
    global.helpText.("ping").short = "Ping a registry"
}

define HandlePingCommand {
    if (command == "ping") {
        handled = true;

        with (consumeRequest) {
            .parsed << command;
            .options.("registry").count = 1
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);

        if (is_defined(command.options.registry)) {
            registry = command.options.registry
        } else {
            registry = "public"
        };
        println@Console(registry)();

        ping@JPM(registry)();
        println@Console("OK")()
    }
}

