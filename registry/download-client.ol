include "registry.iol"
include "console.iol"
include "string_utils.iol"
include "file.iol"
include "pkg" "pkg.iol"

outputPort Registry {
    Location: "socket://localhost:12345"
    Protocol: sodep
    Interfaces: IRegistry
}

define print_value {
    valueToPrettyString@StringUtils(value)(prettyValue);
    println@Console(prettyValue)()
}

main
{
    authenticate@Registry({ .username = "foo", .password = "bar" })(authRes);
    if (authRes) {
        baseMessage << { .token = authRes.token };

        scope(pkgScope) {
            install(InvalidArgumentFault => 
                println@Console(InvalidArgumentFault.message)()
            );

            downloadRequest.packageIdentifier = "dummy_package";
            downloadRequest.version.major = 4;
            downloadRequest.version.minor = 22;
            downloadRequest.version.patch = 1;

            download@Registry(downloadRequest)(value);
            println@Console(value.res)();
            println@Console(value.message)();

            if (is_defined(value.payload)) {
                writeFile@File({ 
                    .content = value.payload,
                    .filename = "tmp/download.pkg"
                })()
            }
        }
    }
}
