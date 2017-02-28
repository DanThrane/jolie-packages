// Include commands
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

