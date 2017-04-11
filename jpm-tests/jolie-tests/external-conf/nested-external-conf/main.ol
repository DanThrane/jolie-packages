include "json_utils.iol"
include "console.iol"

type CustomType: string {
    .inner: bool
}

init {
    A -> global.params.A;
    B -> global.params.B;
    C -> global.params.C
}

main {
    getJsonString@JsonUtils(A)(prettyA);
    println@Console("A")();
    println@Console(prettyA)();

    getJsonString@JsonUtils(B)(prettyB);
    println@Console("B")();
    println@Console(prettyB)();

    getJsonString@JsonUtils(C)(prettyC);
    println@Console("C")();
    println@Console(prettyC)()
}

