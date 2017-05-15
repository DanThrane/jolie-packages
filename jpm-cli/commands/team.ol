init {
    global.helpText.("team") = "
Command for managing teams associated with a registry.

Usage: jpm team [--registry <REG-NAME>] <SUBCOMMAND>

<REG-NAME> defaults to 'public' if not provided.

Available sub-commands:
-----------------------
create <TEAM>           Creates a new team
list <TEAM>             Lists members of a team
add <TEAM> <USER>       Adds <USER> to <TEAM>
remove <TEAM> <USER>    Removes <USER> from <TEAM>
promote <TEAM> <USER>   Promotes <USER> to admin in <TEAM>
demote <TEAM> <USER>    Demotes <USER> from admin in <TEAM>
    ";
    trim@StringUtils(global.helpText.("team"))(global.helpText.("team"));
    global.helpText.("team").short = "Team"
}

define RequireUser {
    if (!is_defined(user)) {
        throw(CLIFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Expected a user to add"
        })
    }
}

define HandleTeamCommand {
    if (command == "team") {
        handled = true;

        with (consumeRequest) {
            .parsed << command;
            .options.registry.count = 1
        };
        consumeRequest.parsed = null;
        consumeOptions@ArgumentParser(consumeRequest)(command);

        registry -> command.options.registry;
        if (!is_defined(registry)) registry = "public";

        subCommand = command.args[0];
        if (#command.args <= 1) {
            throw(CLIFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Usage: jpm team <SUB-COMMAND> <TEAM> [<ARGS>]"
            })
        };

        team = command.args[1];
        user = command.args[2];

        if (subCommand == "create") {
            createTeam@JPM({ .teamName = team, .registry = registry })()
        } else if (subCommand == "add") {
            RequireUser;
            addTeamMember@JPM({
                .teamName = team,
                .username = user,
                .registry = registry
            })()
        } else if (subCommand == "remove") {
            RequireUser;
            removeTeamMember@JPM({
                .teamName = team,
                .username = user,
                .registry = registry
            })()
        } else if (subCommand == "promote") {
            RequireUser;
            promoteTeamMember@JPM({
                .teamName = team,
                .username = user,
                .registry = registry
            })()
        } else if (subCommand == "demote") {
            RequireUser;
            demoteTeamMember@JPM({
                .teamName = team,
                .username = user,
                .registry = registry
            })()
        } else if (subCommand == "list") {
            listTeamMembers@JPM({
                .teamName = team,
                .registry = registry
            })(out);

            println@Console("Found " + #out.members +
                    " members in " + team + ":")();
            for (i = 0, i < #out.members, i++) {
                println@Console("  - " + out.members[i])()
            }
        } else {
            throw(CLIFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unknown subcommand '" + subCommand + "'"
            })
        }
    }
}

