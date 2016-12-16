package dk.thrane.jolie.packages;

import java.util.Arrays;

public enum JolieNativeType {
    STRING(0),
    BOOL(1),
    INT(2),
    LONG(3),
    DOUBLE(4);

    private final int identifier;

    JolieNativeType(int identifier) {
        this.identifier = identifier;
    }

    public static JolieNativeType fromIdentifier(int identifier) {
        return Arrays.stream(values()).filter(it -> it.identifier == identifier).findFirst().orElse(null);
    }

    public int getIdentifier() {
        return identifier;
    }
}
