init {
    global.helpText.("upgrade") = "Upgrade";
    trim@StringUtils(global.helpText.("upgrade"))(global.helpText.("upgrade"));
    global.helpText.("upgrade").short = "Upgrade"
}

define HandleUpgradeCommand {
    if (command == "upgrade") {
        handled = true;
        upgrade@JPM()()
    }
}

