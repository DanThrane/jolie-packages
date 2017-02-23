type MustacheRenderRequest: void {
    .handle: int
    .model: undefined
}

interface IMustache {
    RequestResponse:
        compileTemplateFromFile(string)(int),
        compileTemplateFromString(string)(int),
        renderTemplate(MustacheRenderRequest)(string),
        reset(void)(void)
}

outputPort Mustache {
    Interfaces: IMustache
}

embedded {
    Java:
        "dk.thrane.jolie.mustache.MustacheService" in Mustache
}

