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
    println@Console("Reloading templates!")();
    // Compile templates
    reset@Mustache()();
    compileTemplateFromFile@Mustache("base.mustache")(templates.base);
    compileTemplateFromFile@Mustache("test.mustache")(templates.test);
    compileTemplateFromFile@Mustache("search.mustache")(templates.search);
    compileTemplateFromFile@Mustache("info.mustache")(templates.info);
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
    baseRenderRequest.model.pkg -> global.currentPackage;
    baseRenderRequest.model.req -> req.data;
    renderTemplate@Mustache(baseRenderRequest)(res);

    undef(Render)
}

init {
    // Set the default format as JSON
    format = "json";
    LoadTemplates;
    setContext@JPM(args[0])();
    pkgInfo@JPM()(global.currentPackage)
}

main {
    [get(req)(res) {
        if (req.operation == "search") {
            query@JPM({ .query = req.data.q })(renderReq.model.results);
            renderReq.handle = templates.searchResults;
            renderReq.model.q = req.data.q;
            valueToPrettyString@StringUtils(renderReq.model.results)(pretty);
            println@Console(pretty)();
            renderTemplate@Mustache(renderReq)(Render.body);
            Render.title = "Results";

            Render
        } else if (req.operation == "") {
            renderReq.handle = templates.info;
            renderReq.model << global.currentPackage;
            renderTemplate@Mustache(renderReq)(Render.body);
            Render.title = "Home";

            Render
        } else {
            status = 404;
            Render.body = "404 Not Found";
            Render.title = "Not Found";

            Render
        }
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

