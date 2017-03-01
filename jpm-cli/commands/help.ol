init {
    global.helpText.("help").short = "This command";

    builder = "JPM - The Jolie Package Manager
Version 0.1.0

Usage: jpm <COMMAND> <COMMAND-ARGUMENTS>

Command specific help: jpm help <COMMAND>

Available commands:
-------------------
";
    currentHelpText -> global.helpText.(command);
    foreach (command : global.helpText) {
        builder += "%-15s%s\n";
        builder.args[#builder.args] = command;
        builder.args[#builder.args] = currentHelpText.short
    };
    format@ConsoleUI(builder)(builder);

    global.helpText.("help") = builder;
    undef(builder)
}

define HandleHelpCommand {
    if (command == "help") {
        handled = true;
        if (is_defined(command.args[0])) {
            subCommand = command.args[0];
            if (is_defined(global.helpText.(subCommand))) {
                println@Console(global.helpText.(subCommand))()
            } else {
                println@Console("Unknown command '" + subCommand + "'")()
            }
        } else {
            println@Console(global.helpText.("help"))()
        }
    }
}

