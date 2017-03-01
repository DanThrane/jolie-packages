type SemVer: void {
    .major: int
    .minor: int
    .patch: int
    .label?: string
}

type SemVerExpression: string

type IncrementVersionRequest: string {
    .type: int
}

type SatisfiesVersionRequest: void {
    .version: string
    .range: string
}

type SemVerSortRequest: void {
    .versions[1, *]: SemVer
    .satisfying?: string
}

type SemVerSortResponse: void {
    .versions[0, *]: SemVer
}

constants {
    VERSION_MAJOR = 1,
    VERSION_MINOR = 2,
    VERSION_PATCH = 3
}

interface ISemanticVersion {
    RequestResponse:
        parseVersion(string)(SemVer),
        incrementVersion(IncrementVersionRequest)(string)
            throws InvalidSemVerFieldType, InvalidVersion,
        satisfies(SatisfiesVersionRequest)(bool),
        validatePartial(string)(bool),
        validateVersion(string)(bool),
        convertToString(SemVer)(string),
        sort(SemVerSortRequest)(SemVerSortResponse)
}

outputPort SemVer {
    Interfaces: ISemanticVersion
}

embedded {
    Java:
        "dk.thrane.jolie.semver.SemVer" in SemVer
}
