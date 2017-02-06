type PackRequest: void {
    .packageLocation: string
    .zipLocation: string
    .name: string
}

interface IPkg {
    RequestResponse:
        pack(PackRequest)(void) throws InvalidArgumentFault, IOExceptionFault
}

outputPort Pkg {
    Interfaces: IPkg
}

embedded {
    Java:
        "dk.thrane.jolie.pkg.PkgService" in Pkg 
}
