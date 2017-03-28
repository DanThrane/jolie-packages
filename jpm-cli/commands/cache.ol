init {
    global.helpText.("cache") = "
Command which deals with the cache.

Usage: jpm cache <SUBCOMMAND>

Available sub-commands:
-----------------------
clear       Clear the cache
";
    trim@StringUtils(global.helpText.("cache"))(global.helpText.("cache"));
    global.helpText.("cache").short = "Interact with the cache"
}

define HandleCacheCommand {
    if (command == "cache") {
        handled = true;

        subCommand = command.args[0];
        if (subCommand == "clear") {
            clearCache@JPM()()
        } else {
            println@Console("Unknown subcommand '" + subCommand + "'")()
        }
    }
}

