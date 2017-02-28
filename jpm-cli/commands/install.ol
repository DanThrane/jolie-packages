init {
    global.helpText.("install") = "
Installs the dependencies of this package.

Dependencies are loaded from package.json .... TODO
";
    trim@StringUtils(global.helpText.("install"))(global.helpText.("install"));
    global.helpText.("install").short = "Install dependencies"
}

define HandleInstallCommand {
    if (command == "install") {
        handled = true;
        installDependencies@JPM()()
    }
}

