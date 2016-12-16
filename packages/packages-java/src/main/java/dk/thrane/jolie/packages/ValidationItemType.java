package dk.thrane.jolie.packages;

import java.util.Arrays;

public enum ValidationItemType {
    INFO(0),
    WARNING(1),
    ERROR(2);

    private final int identifier;

    ValidationItemType(int identifier) {
        this.identifier = identifier;
    }

    public int getIdentifier() {
        return identifier;
    }

    public static ValidationItemType fromIdentifier(int identifier) {
        return Arrays.stream(values()).filter(it -> it.getIdentifier() == identifier).findFirst().orElse(null);
    }
}
