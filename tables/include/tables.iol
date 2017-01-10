type ToTextTableRequest: void {
    .headers[0, *]: undefined
    .values[0, *]: undefined
}

interface ITables {
    RequestResponse:
        toTextTable(ToTextTableRequest)(string)
}

outputPort Tables {
    Interfaces: ITables
}

embedded {
    Java:
        "dk.thrane.jolie.tables.TablesService" in Tables
}
