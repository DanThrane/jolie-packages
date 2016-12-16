include "semver.iol"
include "console.iol"
include "string_utils.iol"

outputPort SemVer {
    Interfaces: ISemanticVersion
}

embedded {
    Jolie:
        "main.ol" in SemVer
}

define print_value {
    valueToPrettyString@StringUtils(value)(prettyValue);
    println@Console(prettyValue)()
}

main
{
    value -> output;

    parseVersion@SemVer("1.2.3")(output);
    print_value;

    parseVersion@SemVer("1.2.3-label")(output);
    print_value;

    parseVersion@SemVer("10.20.30")(output);
    print_value;

    parsePartial@SemVer("10.X.30")(output);
    print_value;

    parsePartial@SemVer("10.X")(output);
    print_value;

    parsePartial@SemVer("10.*")(output);
    print_value;

    parsePartial@SemVer("10.x")(output);
    print_value;

    parsePartial@SemVer("*")(output); 
    print_value;

    parsePartial@SemVer("x.X.*")(output); 
    print_value;

    //parsePartial@SemVer("æøå")(output);
    //value -> output; print_value;

    parseRange@SemVer("=1.2.3")(output); 
    print_value;
    
    parseRange@SemVer(">1.2.3")(output); 
    print_value;
    
    parseRange@SemVer("<=1.2.3")(output); 
    print_value;
    
    parseRange@SemVer(">=1.2.3")(output); 
    print_value;
    
    parseRange@SemVer(">1.2.3")(output); 
    print_value;
    
    parseRange@SemVer("      >1.2.3     ")(output); 
    print_value;

    nullProcess
}   
