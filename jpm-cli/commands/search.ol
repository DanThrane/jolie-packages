init {
    global.helpText.("search") = "
Searches known registries for a package.

Usage: jpm search <query>
";
    trim@StringUtils(global.helpText.("search"))(global.helpText.("search"));
    global.helpText.("search").short = "Searches repositories for a package"
}

define HandleSearchCommand {
    if (command == "search") {
        handled = true;

        query -> command.args[0];
        query@JPM({ .query = query })(results);

        rowSep = "|";
        repeat@ConsoleUI({ .char = "-", .count = 22 })(part);
        rowSep += part;
        rowSep += "|";
        repeat@ConsoleUI({ .char = "-", .count = 22 })(part);
        rowSep += part;
        rowSep += "|";
        repeat@ConsoleUI({ .char = "-", .count = 12 })(part);
        rowSep += part;
        rowSep += "|";
        repeat@ConsoleUI({ .char = "-", .count = 12 })(part);
        rowSep += part;
        rowSep += "|";

        foreach (repository : results) {
            b += "@|bold In repository: %s|@\n\n";
            b += rowSep + "\n";
            // Need to add the length of formatting, otherwise we won't get the
            // correct formatting.
            b += "| %-29s | %-29s | %-19s | %-19s |\n";
            b += rowSep + "\n";
            b.args[0] = repository;
            b.args[1] = "@|bold Name|@";
            b.args[2] = "@|bold Description|@";
            b.args[3] = "@|bold Version|@";
            b.args[4] = "@|bold License|@";

            r.values -> results.(repository).results;

            currentValue -> r.values[i];
            for (i = 0, i < #r.values, i++) {
                version << {
                    .major = currentValue.major,
                    .minor = currentValue.minor,
                    .patch = currentValue.patch,
                    .label = currentValue.label
                };
                convertToString@SemVer(version)(versionString);

                b += "| %-20s | %-20s | %-10s | %-10s |\n";
                b.args[#b.args] = currentValue.packageName;
                b.args[#b.args] = currentValue.description;
                b.args[#b.args] = versionString;
                b.args[#b.args] = currentValue.license
            };
            b += rowSep + "\n";
            printfc@ConsoleUI(b)()
        }
    }
}

