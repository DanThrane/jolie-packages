include "packages.iol"
include "string_utils.iol"
include "console.iol"
include "file.iol"

outputPort Packages {
    Location: "socket://localhost:8888"
    Protocol: sodep
    Interfaces: IPackages
}

main
{
    readFile@File({ .filename = "package.json" })(data);
    validate@Packages({ .data = data })(resp);
    valueToPrettyString@StringUtils(resp)(prettyResp);
    println@Console(prettyResp)()
}
