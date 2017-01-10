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

            packageName = args[0];

            println@Console("Creating .pkg file")();
            pkgRequest.zipLocation = "tmp";
            pkgRequest.packageLocation = "../data/" + packageName;
            pack@Pkg(pkgRequest)();

            println@Console("Reading back temporary .pkg file")();
            readFile@File({
                .filename = "tmp/" + packageName + ".pkg",
                .format = "binary"
            })(payload);

            println@Console("Creating package")();
            createPkgReq << baseMessage;
            createPkgReq.name = packageName;
            createPackage@Registry(createPkgReq)(ignored);

            println@Console("Publishing new version")();
            publish@Registry({
                .package = packageName,
                .payload = payload
            })(value);
            print_value
        }
        
    }
}
