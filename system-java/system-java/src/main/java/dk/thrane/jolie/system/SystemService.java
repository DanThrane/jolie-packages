package dk.thrane.jolie.system;

import jolie.runtime.JavaService;
import jolie.runtime.embedding.RequestResponse;

public class SystemService extends JavaService {
    @RequestResponse
    public String getEnv(String key) {
        return System.getenv(key);
    }

    @RequestResponse
    public String getProperty(String key) {
        return System.getProperty(key);
    }

    @RequestResponse
    public String getJavaVersion() {
        return System.getProperty("java.version");
    }

    @RequestResponse
    public String getJavaVendor() {
        return System.getProperty("java.vendor");
    }

    @RequestResponse
    public String getJavaVendorUrl() {
        return System.getProperty("java.vendor.url");
    }

    @RequestResponse
    public String getTemporaryDirectory() {
        return System.getProperty("java.io.tmpdir");
    }

    @RequestResponse
    public String getOperatingSystemName() {
        return System.getProperty("os.name");
    }

    @RequestResponse
    public String getOperatingSystemArchitecture() {
        return System.getProperty("os.arch");
    }

    @RequestResponse
    public String getOperatingSystemVersion() {
        return System.getProperty("os.version");
    }

    @RequestResponse
    public String getFileSeparator() {
        return System.getProperty("file.separator");
    }

    @RequestResponse
    public String getPathSeparator() {
        return System.getProperty("path.separator");
    }

    @RequestResponse
    public String getLineSeparator() {
        return System.getProperty("line.separator");
    }

    @RequestResponse
    public String getUserName() {
        return System.getProperty("user.name");
    }

    @RequestResponse
    public String getUserHomeDirectory() {
        return System.getProperty("user.home");
    }
}
