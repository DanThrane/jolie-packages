type SemVer: void {
    .major: int
    .minor: int
    .patch: int
    .label?: string
}

type SemVerPartial: void {
    .major: int
    .minor: int
    .patch: int
}

type SemVerRange: void {
    .comparator: int
    .partial: SemVerPartial
}

type SemVerRangeSet: void {
    .ranges[1,*]: SemVerRange
}

type VersionSatisfiesRangeRequest: void {
    .version: SemVer
    .range: SemVerRangeSet
}

type VersionComparisonRequest: void {
    .left: SemVer
    .right: SemVer
}

constants {
    COMPARATOR_LESSER = -1,
    COMPARATOR_EQUAL = 0,
    COMPARATOR_GREATER = 1,
    COMPARATOR_LESSER_EQUAL = -2,
    COMPARATOR_GREATER_EQUAL = 2
}

interface ISemanticVersion {
    RequestResponse:
        parseVersion(string)(SemVer) throws InvalidInputFault,
        parsePartial(string)(SemVerPartial) throws InvalidInputFault,
        parseRange(string)(SemVerRange) throws InvalidInputFault,
        parseRangeSet(string)(SemVerRangeSet) throws InvalidInputFault,
        compareVersions(VersionComparisonRequest)(int),
        versionSatisfiesRange(VersionSatisfiesRangeRequest)(bool)
}
