package dk.thrane.jolie.execution;

import jolie.Interpreter;
import jolie.runtime.FaultException;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;
import jolie.runtime.embedding.RequestResponse;

import java.io.File;
import java.io.IOException;
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
            return start.waitFor();
        } catch (IOException e) {
            throw new FaultException(e);
        } catch (InterruptedException e) {
            return -1;
        }
    }

    private Stream<Value> valuesStream(ValueVector vector) {
        return StreamSupport.stream(
                Spliterators.spliteratorUnknownSize(vector.iterator(), Spliterator.ORDERED),
                false);
    }

}
