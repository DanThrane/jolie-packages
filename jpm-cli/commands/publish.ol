init {
    global.helpText.("publish") = "
Publishes this package.
";
    trim@StringUtils(global.helpText.("publish"))(global.helpText.("publish"));
    global.helpText.("publish").short = "Publish this package"
}

define HandlePublishCommand {
    if (command == "publish") {
        handled = true;
        publish@JPM()()
    }
}

