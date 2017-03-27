include "json_utils.iol"
include "console.iol"

type CustomType: string {
    .inner: bool
}

constants {
    A: undefined,
    B: undefined,
    C: void { .a: void { .b: int { .c: int } } }
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

