include "execution.iol" from "execution"
include "string_utils.iol"

init {
    global.helpText.("start") = "
Starts the package placed in the working directory.

Usage: jpm start [OPTIONS] [PROGRAM-ARGUMENTS]

Options:

--conf <profile> <configurationFile>: Uses a deployment profile
--verbose: Verbose output
--debug <suspend> <port>: Uses joliedebug as the interpreter
--trace: Turns on trace output
";
    trim@StringUtils(global.helpText.("start"))(global.helpText.("start"));
    global.helpText.("start").short = "Start this package."
}

define HandleStartCommand {
    if (command == "start") {
        handled = true;

        with (consumeRequest) {
            .parsed << command;
            .options.("conf").count = 2;
            .options.("verbose").count = 0;
            .options.("trace").count = 0;
            .options.("debug").count = 2
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);

        startReq.isVerbose = is_defined(command.options.verbose);
        startReq.trace = is_defined(command.options.trace);

        isDebug = is_defined(command.options.debug);
        if (isDebug) {
            startReq.debug.suspend = command.options.debug[0] == "y";
            startReq.debug.port = int(command.options.debug[1])
        };

        isConfiguring = is_defined(command.options.conf);
        if (isConfiguring) {
            startReq.config.profile = command.options.conf[0];
            startReq.config.file = command.options.conf[1]
        };

        for (i = 0, i < #command.args, i++) {
            startReq.args[#startReq.args] = command.args[i]
        };
        startReq.check = false;

        start@JPM(startReq)()
    }
}

