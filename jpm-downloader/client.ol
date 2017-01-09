include "downloader.iol"

outputPort Downloader {
    Interfaces: IDownloader
}

embedded {
  Jolie: "main.ol" in Downloader
}

main {
    installDependency@Downloader({
        .major = 4,
        .minor = 22,
        .patch = 1,
        .name = "dummy_package",
        .registryLocation = "socket://localhost:12346",
        .targetPackage = "../data/target"
    })()
}
