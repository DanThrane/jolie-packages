package dk.thrane.jolie.checksum;

import jolie.runtime.FaultException;
import jolie.runtime.Value;
import jolie.runtime.embedding.RequestResponse;
import jolie.runtime.JavaService;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.function.Consumer;

public class ChecksumService extends JavaService {
    private final static char[] hexArray = "0123456789ABCDEF".toCharArray();

    public static String bytesToHex(byte[] bytes) {
        char[] hexChars = new char[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }
        return new String(hexChars);
    }

    @RequestResponse
    public String directoryDigest(Value request) throws FaultException {
        // TODO Probably want to skip some files here.
        String algorithm = request.getFirstChild("algorithm").strValue();
        String directory = request.getFirstChild("file").strValue();

        File dir = new File(directory);

        if (!dir.exists()) {
            throw new FaultException("FileNotFound", "Directory not found: '" + dir.getAbsolutePath() + "'");
        }

        MessageDigest instance;
        try {
            instance = MessageDigest.getInstance(algorithm);
        } catch (NoSuchAlgorithmException e) {
            throw new FaultException("AlgorithmNotFound", "Algorithm not found '" + algorithm + "'");
        }

        try {
            byte[] buffer = new byte[32768];
            Files.walk(dir.toPath()).forEachOrdered(catchAll(it -> {
                if (!Files.isDirectory(it)) {
                    InputStream is = Files.newInputStream(it);
                    int read;
                    while ((read = is.read(buffer)) != -1) {
                        instance.update(buffer, 0, read);
                    }
                }
            }));
        } catch (IOException e) {
            throw new FaultException("IOException", e);
        }

        return bytesToHex(instance.digest());
    }

    private <T> Consumer<T> catchAll(UnsafeConsumer<T> consumer) {
        return (T it) -> {
            try {
                consumer.consume(it);
            } catch (Throwable e) {
                throw new RuntimeException(e);
            }
        };
    }

    private static interface UnsafeConsumer<T> {
        void consume(T it) throws Throwable;
    }

    public static void main(String[] args) throws FaultException {
        Value request = Value.create();
        request.getFirstChild("algorithm").setValue("sha-256");
        request.getFirstChild("file").setValue("/home/dan/projects/jolie-packages/jpm-tests/jolie-tests/publish/install-target-newest");

        ChecksumService service = new ChecksumService();
        System.out.println(service.directoryDigest(request));
    }

}
