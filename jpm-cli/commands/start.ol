include "execution" "execution.iol"
include "string_utils.iol"

init {
    global.helpText.("start") = "
Starts the package placed in the working directory.

Usage: jpm start [OPTIONS] [PROGRAM-ARGUMENTS]

Options:

--deploy <profile> <configurationFile>: Uses a deployment profile
--verbose: Verbose output
--debug <suspend> <port>: Uses joliedebug as the interpreter
";
    trim@StringUtils(global.helpText.("start"))(global.helpText.("start"));
    global.helpText.("start").short = "Start this package."
}

define HandleStartCommand {
    if (command == "start") {
        handled = true;

        EventHandle.in.name = "pre-start";
        EventHandle;

        with (consumeRequest) {
            .parsed << command;
            .options.("deploy").count = 2;
            .options.("verbose").count = 0;
            .options.("debug").count = 2
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);

        startReq.isVerbose = is_defined(command.options.verbose);

        isDebug = is_defined(command.options.debug);
        if (isDebug) {
            startReq.debug.suspend = command.options.debug[0] == "y";
            startReq.debug.port = int(command.options.debug[1])
        };

        isDeploying = is_defined(command.options.deploy);
        if (isDeploying) {
            startReq.deployment.profile = command.options.deploy[0];
            startReq.deployment.file = command.options.deploy[1]
        };

        for (i = 0, i < #command.args, i++) {
            startReq.args[#startReq.args] = command.args[i]
        };

        start@JPM(startReq)();

        EventHandle.in.name = "post-start";
        EventHandle
    }
}

