init {
    global.helpText.("start") = "
Starts the package placed in the working directory.

Usage: jpm start [OPTIONS] [PROGRAM-ARGUMENTS]

Options:

--deploy <profile> <configurationFile>: Uses a deployment profile
--verbose: Verbose output
";
    trim@StringUtils(global.helpText.("start"))(global.helpText.("start"));
    global.helpText.("start").short = "Start this package."
}

define HandleStartCommand {
    if (command == "start") {
        handled = true;

        with (consumeRequest) {
            .parsed << command;
            .options.("deploy").count = 2;
            .options.("verbose").count = 0
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);

        startReq.isVerbose = is_defined(command.options.verbose);

        isDeploying = is_defined(command.options.deploy);
        if (isDeploying) {
            startReq.deployment.profile = command.options.deploy[0];
            startReq.deployment.file = command.options.deploy[1]
        };

        for (i = 0, i < #command.args, i++) {
            startReq.args[#startReq.args] = command.args[i]
        };

        start@JPM(startReq)()
    }
}

