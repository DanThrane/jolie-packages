constants {
    PROGRESS_BAR_INDETERMINATE = 0,
    PROGRESS_BAR_PERCENTAGE = 1
}

type LogMessage: string {
    .extra?: undefined
}

type CreateProgressBarRequest: void {
    .name: string
    .type: int
}

type UpdateProgressBarRequest: int {
    .status: int
}

interface ILogger {
    OneWay:
        info(LogMessage),
        warning(LogMessage),
        error(LogMessage),
        updateProgress(UpdateProgressBarRequest)
    RequestResponse:
        createProgress(CreateProgressBarRequest)(int),
        destroyProgress(int)(void)
}

