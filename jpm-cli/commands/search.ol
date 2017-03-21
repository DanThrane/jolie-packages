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

        foreach (repository : results) {
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

                b += "@|bold %s@%s|@/%s @|green %s|@\n";
                b += "  %s\n\n";
                b.args[#b.args] = currentValue.packageName;
                b.args[#b.args] = versionString;
                b.args[#b.args] = repository;
                b.args[#b.args] = currentValue.license;
                b.args[#b.args] = currentValue.description
            };
            if (#r.values == 0) {
                printfc@ConsoleUI("No results in %s" {
                    .args[0] = repository
                })()
            } else {
                printfc@ConsoleUI(b)()
            }
        }
    }
}

