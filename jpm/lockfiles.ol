include "lockfiles.iol"
include "file.iol"
include "semver" "semver.iol"

execution { sequential }

/**
 * @input fileName: string
 * @output lockFile: LockFile
 * @output isDirty: bool
 */
define AssertLockFile {
    if (!is_defined(global.lockFiles.(fileName))) {
        throw(LockFileFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Lock file (" + fileName + ") has not been opened yet!"
        })
    };
    lockFile -> global.lockFiles.(fileName);
    isDirty -> global.dirty.(fileName)
}

/**
 * @input fileName: string
 * @output lockFile: LockFile
 * @output isDirty: bool
 */
define FlushLockFile {
    AssertLockFile;

    if (isDirty) {
        with (writeRequest) {
            .filename = fileName + FILE_SEP + "jpm_lock.json";
            .format = "json";
            .content << lockFile
        };
        writeFile@File(writeRequest)()
    }
}

/**
 * @input .dep: Dependency
 * @output key: string
 */
define GetKey {
    ns -> GetKey;
    key = ns.in.dep.name + "@" + ns.in.dep.version + "/" + ns.in.dep.registry
}

inputPort LockFiles {
    Location: "local"
    Interfaces: ILockFiles
}

init {
    install(LockFileFault => nullProcess);
    getFileSeparator@File()(FILE_SEP)
}

main {
    [open(fileName)() {
        require = false;
        if (is_defined(fileName.require)) require = fileName.require;

        scope (s) {
            install(FileNotFound =>
                if (require) {
                    throw(LockFileFault, {
                        .type = FAULT_BAD_REQUEST,
                        .message = "File '" + fileName + "' was not found!"
                    })
                } else {
                    global.lockFiles.(fileName)._note = "Auto-generated";
                    global.dirty.(fileName) = true
                }
            );

            install(IOException =>
                throw(LockFileFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "IOException when reading file. " +
                        "Is JPM allowed to read file: '" + fileName + "'?"
                })
            );

            readFile@File({
                .filename = fileName + FILE_SEP + "jpm_lock.json",
                .format = "json"
            })(global.lockFiles.(fileName));
            global.dirty.(fileName) = false
        }
    }]

    [isLocked(request)(response) {
        fileName = request;
        AssertLockFile;

        GetKey.in -> request;
        GetKey;

        resolved -> lockFile.locked.(key).resolved;
        response = is_defined(resolved);
        if (response) {
            parseVersion@SemVer(resolved)(response.locked)
        }
    }]

    [lock(request)() {
        fileName = request;
        AssertLockFile;

        GetKey.in -> request;
        GetKey;

        r -> request.resolved;
        global.dirty.(fileName) = true;
        lockFile.locked.(key).resolved = r.major + "." + r.minor +
            "." + r.patch
    }]

    [flush(fileName)() {
        FlushLockFile
    }]

    [close(fileName)() {
        FlushLockFile;

        undef(global.lockFiles.(fileName));
        undef(global.dirty.(fileName))
    }]
}

