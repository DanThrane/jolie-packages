init {
    global.helpText.("whoami") = "
Outputs the user you're logged in as with a registry.

Usage: jpm whoami [--registry <NAME>]

If no registry is given it will be set to 'public'.
";
    trim@StringUtils(global.helpText.("whoami"))(global.helpText.("whoami"));
    global.helpText.("whoami").short = "Checks who you are"
}

define HandleWhoamiCommand {
    if (command == "whoami") {
        handled = true;

        whoami@JPM()(res);
        println@Console(res)()
    }
}

