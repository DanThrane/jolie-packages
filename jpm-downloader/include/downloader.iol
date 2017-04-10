include "utils.iol" from "jpm-utils"

type InstallRequest: void {
    .major: int
    .minor: int
    .patch: int
    .name: string
    .registryLocation: string
    .targetPackage: string
    .token?: string
}

interface IDownloader {
    RequestResponse:
        installDependency(InstallRequest)(void) throws DownloaderFault(ErrorMessage),
        clearCache(void)(void)
}
