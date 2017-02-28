include "jpm" "jpm.iol"
include "console.iol"
include "console-ui" "console_ui.iol"

init {
    global.helpText.("init") = "
Initializes a repository in the current directory.

This will start a command-line wizard which guides you through the
initialization process. This command will create a new folder in the current
directory with the name of the package.

Example:

$ ls
$ jpm init

Package name: foo
Package description: bar
Author: Dan Sebastian Thrane <dthrane@gmail.com> (github.com/DanThrane)
Private Package?: n

$ ls
foo
";
    trim@StringUtils(global.helpText.("init"))(global.helpText.("init"));
    global.helpText.("init").short = "Initializes a repository"
}

define HandleInitCommand {
    if (command == "init") {
        handled = true;

        displayPrompt@ConsoleUI("Package name")(req.name);
        displayPrompt@ConsoleUI("Package description")(req.description);
        displayPrompt@ConsoleUI("Author: [Format: name <email> (homepage)]")
            (req.authors);
        displayYesNoPrompt@ConsoleUI("Private package?" {
            .defaultValue = true
        })(req.private);
        initializePackage@JPM(req)()
    }
}

