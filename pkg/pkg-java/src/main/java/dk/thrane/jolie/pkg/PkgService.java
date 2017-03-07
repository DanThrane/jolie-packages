package dk.thrane.jolie.pkg;

import jolie.runtime.FaultException;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.embedding.RequestResponse;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public class PkgService extends JavaService {
    public static final String FAULT_INTERNAL = "InternalFault";
    public static final String FAULT_INVALID_ARGUMENT = "InvalidArgumentFault";
    public static final String FAULT_IO_EXCEPTION = "IOExceptionFault";
    public static final String EXTENSION = ".pkg";

    @RequestResponse
    public void pack(Value request) throws FaultException {
        String packageLocation = request.getFirstChild("packageLocation").strValue();
        File outputDir = new File(request.getFirstChild("zipLocation").strValue());
        if (!outputDir.exists() && !outputDir.mkdirs()) {
            throw new FaultException(FAULT_INTERNAL, "Unable to create directory for zip location!");
        }

        File packageDir = new File(packageLocation);
        if (!packageDir.exists()) {
            throw new FaultException(FAULT_INVALID_ARGUMENT, "Package directory does not exist!");
        }
        if (!packageDir.isDirectory()) {
            throw new FaultException(FAULT_INVALID_ARGUMENT, "Given file path does not lead to a directory!");
        }

        String name = request.getFirstChild("name").strValue();
        Path outputPath = new File(outputDir, name + EXTENSION).toPath();

        try {
            packDirectory(packageDir.toPath(), outputPath);
        } catch (IOException e) {
            throw new FaultException(FAULT_IO_EXCEPTION, e);
        }
    }

    private void packDirectory(final Path folder, final Path zipFilePath) throws IOException {
        try (
                FileOutputStream fos = new FileOutputStream(zipFilePath.toFile());
                ZipOutputStream zos = new ZipOutputStream(fos)
        ) {
            Files.walkFileTree(folder, new SimpleFileVisitor<Path>() {
                public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                    zos.putNextEntry(new ZipEntry(folder.relativize(file).toString()));
                    Files.copy(file, zos);
                    zos.closeEntry();
                    return FileVisitResult.CONTINUE;
                }

                public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
                    if (dir.getFileName().toString().equals("jpm_packages")) {
                        return FileVisitResult.SKIP_SUBTREE;
                    }

                    if (!folder.equals(dir)) {
                        zos.putNextEntry(new ZipEntry(folder.relativize(dir).toString() + "/"));
                        zos.closeEntry();
                    }
                    return FileVisitResult.CONTINUE;
                }
            });
        }
    }
}
