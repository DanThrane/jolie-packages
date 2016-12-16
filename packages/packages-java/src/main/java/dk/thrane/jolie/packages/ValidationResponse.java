package dk.thrane.jolie.packages;

import jolie.runtime.Value;
import jolie.runtime.ValueVector;

import java.util.List;

public class ValidationResponse {
    private final List<ValidationItem> items;

    public ValidationResponse(List<ValidationItem> items) {
        this.items = items;
    }

    public List<ValidationItem> getItems() {
        return items;
    }

    public Value toValue() {
        Value value = Value.create();
        ValueVector items = value.getChildren("items");
        this.items.forEach(it -> {
            items.add(it.toValue());
        });
        return value;
    }

}
