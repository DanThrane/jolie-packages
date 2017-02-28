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
            println@Console("In repository: " + repository)();
            println@Console("--------------------------------")();
            tablesRequest.values -> results.(repository).results;

            currentValue -> tablesRequest.values[i];
            for (i = 0, i < #tablesRequest.values, i++) {
                version << {
                    .major = currentValue.major,
                    .minor = currentValue.minor,
                    .patch = currentValue.patch,
                    .label = currentValue.label
                };
                convertToString@SemVer(version)(versionString);
                currentValue.version = versionString;
                undef(currentValue.major);
                undef(currentValue.minor);
                undef(currentValue.patch);
                undef(currentValue.label)
            };

            toTextTable@Tables(tablesRequest)(table);
            println@Console(table)()
        }
    }
}

