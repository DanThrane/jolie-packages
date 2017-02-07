interface ISystem {
    RequestResponse:
        getEnv(string)(string),
        getProperty(string)(string),
        getJavaVersion(void)(string),
        getJavaVendor(void)(string),
        getJavaVendorUrl(void)(string),
        getTemporaryDirectory(void)(string),
        getOperatingSystemName(void)(string),
        getOperatingSystemArchitecture(void)(string),
        getOperatingSystemVersion(void)(string),
        getFileSeparator(void)(string),
        getPathSeparator(void)(string),
        getLineSeparator(void)(string),
        getUserName(void)(string),
        getUserHomeDirectory(void)(string)
}

outputPort System {
    Interfaces: ISystem
}

embedded {
    Java:
        "dk.thrane.jolie.system.SystemService" in System
}
