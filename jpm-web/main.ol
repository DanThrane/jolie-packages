include "mustache" "mustache.iol"
include "string_utils.iol"
include "jpm" "jpm.iol"
include "config.iol"
include "console.iol"

execution { concurrent }

interface IWeb {
    RequestResponse:
        get(undefined)(undefined),
        post(undefined)(undefined),
        put(undefined)(undefined),
        delete(undefined)(undefined),
}

inputPort Web {
    Location: "socket://localhost:8080"
    Interfaces: IWeb
    Protocol: http {
        .statusCode -> statusCode;
        .format -> format;
        .contentType -> contentType;
        .default.get = "get";
        .default.post = "post";
        .default.put = "put";
        .default.delete = "delete"
    }
}

outputPort JPM {
    Interfaces: IJPM
}

embedded {
    JoliePackage:
        "jpm" in JPM
}

define LoadTemplates {
    // Compile templates
    reset@Mustache()();
    compileTemplateFromFile@Mustache("base.mustache")(templates.base);
    compileTemplateFromFile@Mustache("test.mustache")(templates.test);
    compileTemplateFromFile@Mustache("search.mustache")(templates.search);
    compileTemplateFromFile@Mustache
        ("search_results.mustache")(templates.searchResults)
}

define Render {
    if (RELOAD_TEMPLATES) LoadTemplates;

    format = "html";
    if (!is_defined(Render.title)) Render.title = "Missing title";
    if (!is_defined(Render.head)) Render.head = "";
    if (!is_defined(Render.body)) Render.body = "";

    baseRenderRequest.model.title -> Render.title;
    baseRenderRequest.model.body -> Render.body;
    baseRenderRequest.model.head -> Render.head;
    baseRenderRequest.handle = templates.base;
    renderTemplate@Mustache(baseRenderRequest)(res);

    undef(Render)
}

init {
    // Set the default format as JSON
    format = "json";
    LoadTemplates
}

main {
    [get(req)(res) {
        renderReq.handle = templates.test;
        with (renderReq.model) {
            .testing[0] = "1";
            .testing[1] = "2";
            .testing[2] = "C";
            .foo = "foo";
            .bar = "bar";
            .nested[0].name = "foo";
            .nested[0].count = 42;
            .nested[1].name = "bar";
            .nested[1].count = 1337
        };
        renderTemplate@Mustache(renderReq)(Render.body);
        Render.title = "Home";

        Render
    }]

    [post(req)(res) {
        res -> req
    }]

    [put(req)(res) {
        res -> req
    }]

    [delete(req)(res) {
        res -> req
    }]
}

