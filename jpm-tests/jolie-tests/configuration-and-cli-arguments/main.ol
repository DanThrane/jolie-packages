include "console.iol"

parameters {
    TOKEN: string,
    SOME_OTHER_TOKEN: string
}

main {
    println@Console("TOKEN=" + TOKEN)();
    println@Console("SOME_OTHER_TOKEN=" + SOME_OTHER_TOKEN)();
    println@Console("#args=" + #args)();
    for (i = 0, i < #args, i++) {
        println@Console("args[" + i + "]=" + args[i])()
    }
}
