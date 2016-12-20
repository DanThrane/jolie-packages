package dk.thrane.jolie.semver;

import com.github.zafarkhaja.semver.ParseException;
import com.github.zafarkhaja.semver.Version;
import com.github.zafarkhaja.semver.expr.ExpressionParser;
import jolie.runtime.FaultException;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.embedding.RequestResponse;

import java.util.Arrays;
import java.util.Optional;

public class SemVer extends JavaService {
    public static final String FAULT_INVALID_VERSION = "InvalidVersion";
    enum SemVerFieldType {
        MAJOR(1),
        MINOR(2),
        PATCH(3);
        private final int id;

        SemVerFieldType(int id) {
            this.id = id;
        }

        static SemVerFieldType findBy(int id) throws FaultException {
            return Arrays.stream(values()).filter(it -> it.id == id).findFirst().orElseThrow(() ->
                    new FaultException("InvalidSemVerFieldType", "Field type with ID " + id + " is not valid!"));
        }
    }

    @RequestResponse
    public Boolean validateVersion(String request) {
        try {
            parseInternalVersion(request);
            return true;
        } catch (FaultException e) {
            return false;
        }
    }

    @RequestResponse
    public Value parseVersion(String request) throws FaultException {
        return convertVersion(parseInternalVersion(request));
    }

    @RequestResponse
    public Boolean validatePartial(String request) {
        try {
            ExpressionParser.newInstance().parse(request);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @RequestResponse
    public String incrementVersion(Value request) throws FaultException {
        requireChildren(request, "type");

        Version version = parseInternalVersion(request.strValue());
        SemVerFieldType fieldType = SemVerFieldType.findBy(request.getFirstChild("type").intValue());

        switch (fieldType) {
            case MAJOR:
                return version.incrementMajorVersion().toString();
            case MINOR:
                return version.incrementMinorVersion().toString();
            case PATCH:
                return version.incrementPatchVersion().toString();
            default:
                throw new FaultException("InternalError");
        }
    }

    @RequestResponse
    public Boolean satisfies(Value request) throws FaultException {
        requireChildren(request, "version", "range");

        Version version = parseInternalVersion(request.getFirstChild("version").strValue());
        return version.satisfies(request.getFirstChild("range").strValue());
    }

    private Version parseInternalVersion(String request) throws FaultException {
        try {
            return Version.valueOf(request);
        } catch (ParseException e) {
            throw new FaultException(FAULT_INVALID_VERSION, e);
        }
    }

    private Value convertVersion(Version version) {
        Value value = Value.create();
        value.getNewChild("major").setValue(version.getMajorVersion());
        value.getNewChild("minor").setValue(version.getMinorVersion());
        value.getNewChild("patch").setValue(version.getPatchVersion());
        value.getNewChild("label").setValue(version.getPreReleaseVersion());
        return value;
    }

    private void requireChildren(Value tree, String... identifiers) throws FaultException {
        Optional<String> optMissingChild = Arrays.stream(identifiers).filter(id -> !tree.hasChildren(id)).findAny();
        if (optMissingChild.isPresent()) {
            throw new FaultException("Missing child '" + optMissingChild.get() + "' in request");
        }
    }
}
