include "utils.iol" from "jpm-utils"
include "packages.iol" from "packages"
include "semver.iol" from "semver"

type LockedDependency: bool {
    .locked?: SemVer
}

type IsDependencyLockedRequest: string {
    .dep: Dependency
}

type LockDependencyRequest: string {
    .dep: Dependency
    .resolved: SemVer
}

type LockFileOpenRequest: string {
    .require?: bool
}

interface ILockFiles {
    RequestResponse:
        open(LockFileOpenRequest)(void)
            throws LockFileFault(ErrorMessage),
        isLocked(IsDependencyLockedRequest)(LockedDependency)
            throws LockFileFault(ErrorMessage),
        lock(LockDependencyRequest)(void)
            throws LockFileFault(ErrorMessage),
        flush(string)(void)
            throws LockFileFault(ErrorMessage),
        close(string)(void)
            throws LockFileFault(ErrorMessage)
}

