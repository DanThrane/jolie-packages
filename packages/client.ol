include "packages.iol"
include "string_utils.iol"
include "console.iol"

outputPort Packages {
	Location: "socket://localhost:8888"
	Protocol: sodep
	Interfaces: IPackages
}

main
{
	validate@Packages({ .location = "." })(resp);
	valueToPrettyString@StringUtils(resp)(prettyResp);
	println@Console(prettyResp)()
}
