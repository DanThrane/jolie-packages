type Arguments: void {
    .args[0, *]: string
    .begin?: int
    .end?: int
}

type ParsedArguments: void {
    .args[0, *]: string
    .options?: undefined
}

type ConsumeRequest: void {
    .parsed: ParsedArguments
    .options: undefined
}

interface IArgumentParser {
    RequestResponse:
        parse(Arguments)(ParsedArguments),
        consumeOptions(ConsumeRequest)(ParsedArguments)
            throws CLIFault(ErrorMessage)
}

