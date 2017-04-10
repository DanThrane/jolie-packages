include "execution.iol" from "execution"
include "string_utils.iol"

init {
    global.helpText.("check") = "
Runs --check on this package

Usage: jpm check [OPTIONS]

Options:

--conf <profile> <configurationFile>: Uses a deployment profile
--verbose: Verbose output
";
    trim@StringUtils(global.helpText.("check"))(global.helpText.("check"));
    global.helpText.("check").short = "Start this package."
}

define HandleCheckCommand {
    if (command == "check") {
        handled = true;

        with (consumeRequest) {
            .parsed << command;
            .options.("conf").count = 2;
            .options.("verbose").count = 0
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);

        checkReq.isVerbose = is_defined(command.options.verbose);
        checkReq.trace = false;

        isConfiguring = is_defined(command.options.config);
        if (isConfiguring) {
            checkReq.config.profile = command.options.config[0];
            checkReq.config.file = command.options.config[1]
        };

        for (i = 0, i < #command.args, i++) {
            checkReq.args[#checkReq.args] = command.args[i]
        };
        checkReq.check = true;

        start@JPM(checkReq)()
    }
}

