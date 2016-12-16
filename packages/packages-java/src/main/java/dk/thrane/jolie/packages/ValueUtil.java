package dk.thrane.jolie.packages;

import jolie.runtime.Value;
import jolie.runtime.ValueVector;

public enum ValueUtil {
    INSTANCE;

    public ValueVector getChildrenOrNull(Value value, String child) {
        return value.hasChildren(child) ? value.getChildren(child) : null;
    }

    public Value getFirstChildOrNull(Value value, String child) {
        return value.hasChildren(child) ? value.getFirstChild(child) : null;
    }
}
