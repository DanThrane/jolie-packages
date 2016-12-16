package dk.thrane.jolie.packages;

import jolie.runtime.Value;

public class ValidationItem {
    private final ValidationItemType type;
    private final String message;

    public ValidationItem(ValidationItemType type, String message) {
        this.type = type;
        this.message = message;
    }

    public ValidationItemType getType() {
        return type;
    }

    public String getMessage() {
        return message;
    }

    public Value toValue() {
        Value value = Value.create();
        value.getNewChild("type").setValue(type.getIdentifier());
        value.getNewChild("message").setValue(message);
        return value;
    }
}
