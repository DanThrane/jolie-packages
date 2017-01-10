include "jpm" "jpm.iol"
include "jpm-utils" "utils.iol"

outputPort JPM {
    Interfaces: IJPM
}

embedded {
    JoliePackage:
        "jpm" in JPM {} // TODO FIXME bug in interpreter. Cfg should be optional
}

define QueryTest {
    query@JPM({ .query = "package" })(results);
    value -> results; DebugPrintValue
}

define DependencyTreeTest {
    setContext@JPM("/home/dan/projects/jolie-packages/data/test")();
    installDependencies@JPM()()
}

main {
    install(ServiceFault =>
        println@Console("An error has occoured!")();
        value -> main.ServiceFault; DebugPrintValue
    );
    DependencyTreeTest    
}
