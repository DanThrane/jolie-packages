package dk.thrane.jolie.tables;

import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;
import jolie.runtime.embedding.RequestResponse;

import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.stream.StreamSupport;

public class TablesService extends JavaService {
    @RequestResponse
    public String toTextTable(Value request) {
        Value header = request.getFirstChild("header");
        ValueVector values = request.getChildren("values");

        Set<String> knownKeys = new HashSet<>();
        valuesStream(values).map(it -> it.children().keySet()).forEach(knownKeys::addAll);

        Map<String, String> headerMapping = new HashMap<>();
        header.children().forEach((key, value) -> headerMapping.put(key, value.first().strValue()));

        TextTableBuilder table = new TextTableBuilder();
        table.addRow(
                knownKeys.stream().map(it -> headerMapping.getOrDefault(it, it)).collect(Collectors.toList())
        );

        List<List<String>> lists = valuesStream(values).map(value ->
                value.children().keySet().stream().map(key -> {
                    if (value.hasChildren(key)) {
                        return value.getFirstChild(key).strValue();
                    } else {
                        return "";
                    }
                }).collect(Collectors.toList())).collect(Collectors.toList());
        lists.forEach(table::addRow);
        return table.toString();
    }

    private Stream<Value> valuesStream(ValueVector vector) {
        return StreamSupport.stream(
                Spliterators.spliteratorUnknownSize(vector.iterator(), Spliterator.ORDERED),
                false);
    }

}
