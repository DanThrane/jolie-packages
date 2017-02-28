include "jpm-utils" "utils.iol"
include "argument-parser.iol"

include "string_utils.iol"
include "console.iol"

execution { sequential }

inputPort ArgumentParser {
    Location: "local"
    Interfaces: IArgumentParser
}

init {
    install(CLIFault => nullProcess)
}

main {
    [parse(req)(command) {
        if (is_defined(req.begin)) begin = req.begin
        else begin = 0;

        if (is_defined(req.end)) end = req.end
        else end = #req.args;

        for (i = begin, i < end, i++) {
            startsWith@StringUtils(req.args[i] { .prefix = "--" })(isOption);

            if (isOption) {
                length@StringUtils(req.args[i])(optionLength);
                substring@StringUtils(req.args[i] {
                    .begin = 2,
                    .end = optionLength
                })(optionName);
                command.options.(optionName) = i - begin
            };

            command.args[i - begin] = req.args[i]
        }
    }]

    [consumeOptions(req)(res) {
        remainingOptions = req.parsed.options;

        currentOption -> req.options.(optionKey);
        foreach (optionKey : req.options) {
            if (is_defined(req.parsed.options.(optionKey))) {
                // Option exists, consume parameters
                baseIndex = req.parsed.options.(optionKey);
                skip.(baseIndex) = true;
                for (i = 1, i <= currentOption.count, i++) {
                    res.options.(optionKey)[i - 1] =
                        req.parsed.args[baseIndex + i];
                    skip.(baseIndex + i) = true;

                    if (baseIndex + i >= #req.parsed.args) {
                        throw(CLIFault, {
                                .type = 400,
                                .message = "Expected " + currentOption.count +
                                    " parameters for option '" +
                                    optionKey + "'"
                        })
                    }
                }
            }
        };

        for (i = 0, i < #req.parsed.args, i++) {
            if (!is_defined(skip.(i))) {
                res.args[#res.args] = req.parsed.args[i]
            }
        }
    }]
}

