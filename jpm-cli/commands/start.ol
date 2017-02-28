init {
    global.helpText.("start") = "
Starts the package placed in the working directory.

Usage: jpm start [OPTIONS] [PROGRAM-ARGUMENTS]

Options:

--deploy <profile> <configurationFile>: Uses a deployment profile
";
    trim@StringUtils(global.helpText.("start"))(global.helpText.("start"));
    global.helpText.("start").short = "Start dependencies"
}

define HandleStartCommand {
    if (command == "start") {
        handled = true;

        isDeploying = is_defined(command.options.("deploy"));
        if (isDeploying) {
            deployIdx = command.options.("deploy");
            startReq.deployment.profile = command.args[deployIdx + 1];
            startReq.deployment.file = command.args[deployIdx + 2]
        };

        // TODO This is not well supported. We need a way of consuming the
        // options
        i = 0;
        if (isDeploying) i = deployIdx + 3;
        for (i = i, i < #command.args, i++) {
            startReq.args[#startReq.args] = command.args[i]
        };

        start@JPM(startReq)()
    }
}

