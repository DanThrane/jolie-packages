package dk.thrane.jolie.execution;

import jolie.Interpreter;
import jolie.runtime.FaultException;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;
import jolie.runtime.embedding.RequestResponse;

import java.io.*;
import java.util.Spliterator;
import java.util.Spliterators;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.stream.StreamSupport;

public class ExecutionService extends JavaService {
    @RequestResponse
    public Integer execute(Value request) throws FaultException {
        boolean suppressIO = request.getFirstChild("suppress").boolValue();
        ValueVector commands = request.getChildren("commands");
        File directory = request.hasChildren("directory") ?
                new File(request.getFirstChild("directory").strValue()) :
                new File(".");
        ProcessBuilder builder = new ProcessBuilder();
        builder.command(valuesStream(commands).map(Value::strValue).collect(Collectors.toList()));
        builder.directory(directory);
        if (!suppressIO) builder.inheritIO();
        try {
            Process start = builder.start();
            Thread outThread = null;
            Thread errThread = null;
            if (!suppressIO) {
                outThread = readFully(start.getInputStream(), System.out);
                errThread = readFully(start.getErrorStream(), System.err);
                outThread.start();
                errThread.start();
            }
            int i = start.waitFor();
            if (!suppressIO) {
                outThread.join();
                errThread.join();
            }
            return i;
        } catch (IOException e) {
            throw new FaultException(e);
        } catch (InterruptedException e) {
            return -1;
        }
    }

    private Thread readFully(InputStream in, PrintStream out) {
        return new Thread(() -> {
            BufferedReader reader = new BufferedReader(new InputStreamReader(in));
            String line;
            try {
                while ((line = reader.readLine()) != null) {
                    out.println(line);
                }
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });
    }

    private Stream<Value> valuesStream(ValueVector vector) {
        return StreamSupport.stream(
                Spliterators.spliteratorUnknownSize(vector.iterator(), Spliterator.ORDERED),
                false);
    }

}
