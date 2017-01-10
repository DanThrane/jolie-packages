type ExecutionRequest: void {
    .suppress: bool
    .commands[1, *]: string
    .directory?: string
}

interface IExecution {
    RequestResponse:
        execute(ExecutionRequest)(int) throws IOException
}

outputPort Execution {
    Interfaces: IExecution
}

embedded {
    Java:
        "dk.thrane.jolie.execution.ExecutionService" in Execution
}
