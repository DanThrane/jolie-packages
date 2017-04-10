type DigestRequest: void {
    .algorithm: string
    .file: string
}

interface IChecksum {
    RequestResponse:
        directoryDigest(DigestRequest)(string)
            throws FileNotFound(string)
                   AlgorithmNotFound(string)
                   IOException(string)
}

outputPort Checksum {
    Interfaces: IChecksum
}

embedded {
    Java:
        "dk.thrane.jolie.checksum.ChecksumService" in Checksum
}

