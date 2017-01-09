include "jpm-utils" "utils.iol"

type InstallRequest: void {
    .major: int
    .minor: int
    .patch: int
    .name: string
    .registryLocation: string
    .targetPackage: string
    .authentication?: void {
        .username: string
        .password: string
    }
}

interface IDownloader {
    RequestResponse:
        installDependency(InstallRequest)(void) throws DownloaderFault(ErrorMessage)
}
