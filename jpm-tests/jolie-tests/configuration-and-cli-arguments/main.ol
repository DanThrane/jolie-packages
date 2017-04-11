include "console.iol"

init {
    TOKEN -> global.params.TOKEN;
    SOME_OTHER_TOKEN -> global.params.SOME_OTHER_TOKEN
}

main {
    println@Console("TOKEN=" + TOKEN)();
    println@Console("SOME_OTHER_TOKEN=" + SOME_OTHER_TOKEN)();
    println@Console("#args=" + #args)();
    for (i = 0, i < #args, i++) {
        println@Console("args[" + i + "]=" + args[i])()
    }
}
