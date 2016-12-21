include "registry.iol"
include "console.iol"
include "string_utils.iol"
include "file.iol"

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
        token = authRes.token;

        getPackageList@Registry()(value);
        print_value;
        
        createPackage@Registry({ .token = token, .name = "baz" })(value);
        print_value;

        getPackageList@Registry()(value);
        print_value;

        getPackageInfo@Registry("baz")(value);
        print_value;

        readFile@File({
            .filename = "testPkg.tar",
            .format = "binary"
        })(payload);

        publish@Registry({
            .package = "baz",
            .payload = payload
        })(value);
        print_value;
        foo = 2 + 2
    }
}

