init {
    global.helpText.("validate") = "Validates the package manifest";
    trim@StringUtils(global.helpText.("validate"))(global.helpText.("validate"));
    global.helpText.("validate").short = "Validates the package manifest"
}

define HandleValidateCommand {
    if (command == "validate") {
        handled = true;
        getPackage@JPM()(ignored);
        println@Console("OK")()
    }
}

