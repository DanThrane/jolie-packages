// Include commands
include "init.ol"
include "install.ol"
include "publish.ol"
include "search.ol"
include "start.ol"
include "check.ol"
include "login.ol"
include "register.ol"
include "logout.ol"
include "whoami.ol"
include "cache.ol"
include "ping.ol"
include "test.ol"
include "validate.ol"
include "team.ol"
include "upgrade.ol"
include "transfer.ol"
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
    HandleCheckCommand;
    HandleLoginCommand;
    HandleRegisterCommand;
    HandleLogoutCommand;
    HandleWhoamiCommand;
    HandleCacheCommand;
    HandlePingCommand;
    HandleValidateCommand;
    HandleTeamCommand;
    HandleTransferCommand;
    HandleUpgradeCommand;
    HandleHelpCommand;
    // end user defined commands

    if (!handled) {
        println@Console("Unknown command '" + command + "'")()
    }
}

