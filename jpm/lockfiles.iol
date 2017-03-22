include "jpm-utils" "utils.iol"
include "packages" "packages.iol"
include "semver" "semver.iol"

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

