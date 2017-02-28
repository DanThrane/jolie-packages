// Include commands
include "init.ol"
include "install.ol"
include "publish.ol"
include "search.ol"
include "start.ol"
include "login.ol"
include "register.ol"
include "logout.ol"
include "whoami.ol"
include "cache.ol"
include "ping.ol"
include "test.ol"
// help command must be last
include "help.ol"

define HandleCommand {
    handled = false;

    // begin user defined commands
    HandleTestCommand;
    HandleInitCommand;
    HandleInstallCommand;
    HandlePublishCommand;
    HandleSearchCommand;
    HandleStartCommand;
    HandleLoginCommand;
    HandleRegisterCommand;
    HandleLogoutCommand;
    HandleWhoamiCommand;
    HandleCacheCommand;
    HandlePingCommand;
    HandleHelpCommand;
    // end user defined commands

    if (!handled) {
        println@Console("Unknown command '" + command + "'")()
    }
}

