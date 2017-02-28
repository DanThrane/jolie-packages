init {
    global.helpText.("test") = "Test";
    trim@StringUtils(global.helpText.("test"))(global.helpText.("test"));
    global.helpText.("test").short = "Test"
}

define HandleTestCommand {
    if (command == "test") {
        handled = true;
        with (consumeRequest) {
            .parsed << command;
            .options.("foo").count = 2;
            .options.("bar").count = 1
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);
        valueToPrettyString@StringUtils(command)(prettyCommand);
        println@Console(prettyCommand)()
    }
}

