package dk.thrane.jolie.mustache;

import com.github.mustachejava.DefaultMustacheFactory;
import com.github.mustachejava.Mustache;
import com.github.mustachejava.MustacheFactory;
import jolie.runtime.FaultException;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;
import jolie.runtime.embedding.RequestResponse;

import java.io.File;
import java.io.IOException;
import java.io.StringReader;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

public class MustacheService extends JavaService {
    public static final String FAULT_NAME = "MustacheFault";

    private final AtomicInteger handles = new AtomicInteger(0);
    private final Mustache[] templates = new Mustache[2048];
    private MustacheFactory factory = new DefaultMustacheFactory();

    @RequestResponse
    public Integer compileTemplateFromFile(String fileName) {
        int handle = handles.getAndIncrement();
        Mustache compile = factory.compile(fileName);
        templates[handle] = compile;
        return handle;
    }

    @RequestResponse
    public Integer compileTemplateFromString(String templateCode) {
        int handle = handles.getAndIncrement();
        Mustache compile = factory.compile(new StringReader(templateCode), "template-" + templateCode.hashCode());
        templates[handle] = compile;
        return handle;
    }

    @RequestResponse
    public String renderTemplate(Value request) throws FaultException {
        int handle = request.getFirstChild("handle").intValue();
        Value model = request.getFirstChild("model");

        Mustache template = templates[handle];
        if (template == null) {
            throw new FaultException(FAULT_NAME, "Unknown handle!");
        }

        try {
            StringWriter outputWriter = new StringWriter();
            template.execute(outputWriter, convertValue(model)).flush();
            return outputWriter.toString();
        } catch (IOException e) {
            throw new FaultException(FAULT_NAME, e);
        }
    }

    @RequestResponse
    public void reset() {
        for (int i = 0; i < templates.length; i++) {
            templates[i] = null;
        }
        handles.set(0);
        factory = new DefaultMustacheFactory(); // Throw out the old cache
    }

    private Object convertValue(Value model) {
        if (model.children().isEmpty()) {
            return model.valueObject();
        } else {
            Map<String, Object> result = new HashMap<>();
            model.children().forEach((k, v) -> result.put(k, convertVector(v)));
            return result;
        }
    }

    private Object convertVector(ValueVector vector) {
        if (vector.size() == 1) {
            return convertValue(vector.get(0));
        } else {
            List<Object> result = new ArrayList<>();
            vector.iterator().forEachRemaining(it -> result.add(convertValue(it)));
            return result;
        }
    }
}
