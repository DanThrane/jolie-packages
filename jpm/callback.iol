type JPMEvent: void {
    .type: string
    .data: undefined
}

interface IJPMCallback {
    OneWay:
        jpmEvent(JPMEvent)
}

