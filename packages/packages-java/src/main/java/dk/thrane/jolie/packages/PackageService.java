package dk.thrane.jolie.packages;

import jolie.runtime.FaultException;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;
import jolie.runtime.embedding.RequestResponse;

import java.net.URI;
import java.net.URISyntaxException;
import java.nio.charset.Charset;
import java.nio.charset.CharsetEncoder;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import java.util.stream.StreamSupport;

import static dk.thrane.jolie.packages.ValidationItemType.*;

public class PackageService extends JavaService {
    private static final CharsetEncoder NAME_ENCODER = Charset.forName("US-ASCII").newEncoder();
    private static final Pattern NAME_ALLOWED_CHARACTERS = Pattern.compile("^[a-zA-Z0-9_-]*$");
    public static final Pattern REGEX_AUTHOR = Pattern.compile("([^\\n\\r()<>]+)(<(\\S+@\\S+)>)?[ \\t]*(\\((\\S*)\\))?");

    @RequestResponse
    public Value validateName(Value request) {
        List<ValidationItem> items = new ArrayList<>();
        internalValidateName(items, request);
        return new ValidationResponse(items).toValue();
    }

    @RequestResponse
    public Boolean requireChild(Value request) {
        Value value = request.getFirstChild("value");
        String child = request.getFirstChild("child").strValue();
        return ValueUtil.INSTANCE.getFirstChildOrNull(value, child) != null;
    }

    @RequestResponse
    public Boolean requireChildOfType(Value request) throws FaultException {
        Value value = request.getFirstChild("value");
        String child = request.getFirstChild("child").strValue();
        JolieNativeType type = JolieNativeType.fromIdentifier(request.getFirstChild("type").intValue());
        Value firstChildOrNull = ValueUtil.INSTANCE.getFirstChildOrNull(value, child);
        if (type == null) throw new FaultException("InvalidIdentifier", "Unknown identifier");
        if (firstChildOrNull == null) return false;

        Object o = firstChildOrNull.valueObject();
        return checkType(type, o);
    }

    @RequestResponse
    public Boolean optionalChildOfType(Value request) throws FaultException {
        Value value = request.getFirstChild("value");
        String child = request.getFirstChild("child").strValue();
        JolieNativeType type = JolieNativeType.fromIdentifier(request.getFirstChild("type").intValue());
        Value firstChildOrNull = ValueUtil.INSTANCE.getFirstChildOrNull(value, child);
        if (type == null) throw new FaultException("InvalidIdentifier", "Unknown identifier");
        if (firstChildOrNull == null) return true;

        Object o = firstChildOrNull.valueObject();
        return checkType(type, o);
    }

    @RequestResponse
    public Boolean isValidLicenseIdentifier(String identifier) {
        return Licenses.ALL.contains(identifier);
    }

    @RequestResponse
    public Value validateAuthors(Value request) {
        Value resp = Value.create();
        ValueVector items = resp.getChildren("items");
        ValueVector authors = ValueVector.create();
        internalValidateAuthors(items, authors, request);
        boolean hasErrors = asStream(items.iterator()).anyMatch(it ->
                it.getFirstChild("type").intValue() == ValidationItemType.ERROR.getIdentifier());
        if (!hasErrors) {
            resp.getChildren("authors").deepCopy(authors);
        }
        return resp;
    }

    private <T> Stream<T> asStream(Iterator<T> sourceIterator) {
        Iterable<T> iterable = () -> sourceIterator;
        return StreamSupport.stream(iterable.spliterator(), false);
    }

    @RequestResponse
    public Boolean validateURI(String uriString) {
        try {
            URI uri = new URI(uriString);
            return uri.getScheme() != null && uri.getHost() != null && uri.getPort() != -1;
        } catch (URISyntaxException e) {
            return false;
        }
    }

    private void internalValidateAuthors(ValueVector items, ValueVector parsedAuthors, Value request) {
        if (request.hasChildren("authors")) {
            ValueVector authors = request.getChildren("authors");
            final int[] i = {0};
            authors.iterator().forEachRemaining(author -> {
                Value parsed = validateAuthor(items, i[0], author);
                if (parsed != null) {
                    parsedAuthors.add(parsed);
                }
                i[0]++;
            });
        }
    }

    private Value validateAuthor(ValueVector items, int i, Value authorValue) {
        if (!(authorValue.valueObject() instanceof String)) {
            items.add(createValidationItem(ERROR, "authors[" + i + "]", "Author must be a string").toValue());
            return null;
        }
        String author = authorValue.strValue();
        Matcher matcher = REGEX_AUTHOR.matcher(author);

        if (matcher.matches()) {
            Value result = Value.create();
            result.setValue(matcher.group(1));

            String email = matcher.group(3);
            if (email != null) {
                result.getFirstChild("email").setValue(email);
            }

            String homepage = matcher.group(5);
            if (homepage != null) {
                result.getFirstChild("homepage").setValue(homepage);
            }
            return result;
        } else {
            items.add(createValidationItem(ERROR, "authors[" + i + "]", "Authors must use the " +
                    "following convention: name [\"<\" email \">\"] [\"(\" homepage \")\"]").toValue());
            return null;
        }
    }

    private Boolean checkType(JolieNativeType type, Object o) throws FaultException {
        switch (type) {
            case STRING:
                return o instanceof String;
            case BOOL:
                return o instanceof Boolean;
            case DOUBLE:
                return o instanceof Double;
            case LONG:
                return o instanceof Long;
            case INT:
                return o instanceof Integer;
            default:
                throw new FaultException("InvalidIdentifier", "Unknown identifier");
        }
    }

    private void internalValidateName(List<ValidationItem> items, Value request) {
        String fieldName = "name";
        if (!request.hasChildren(fieldName)) {
            items.add(createValidationItem(ERROR, fieldName, "field is required"));
            return;
        }

        Object nameObj = request.getFirstChild(fieldName).valueObject();
        if (!(nameObj instanceof String)) {
            items.add(createValidationItem(ERROR, fieldName, "must be a string"));
            return;
        }

        String name = (String) nameObj;
        if (!NAME_ENCODER.canEncode(name)) {
            items.add(createValidationItem(ERROR, fieldName, "must be US-ASCII"));
            return;
        }

        if (!NAME_ALLOWED_CHARACTERS.matcher(name).matches()) {
            items.add(createValidationItem(ERROR, fieldName, "can only contain URI safe characters"));
        }

        if (name.length() > 255) {
            items.add(createValidationItem(ERROR, fieldName, "length must not exceed 255 characters"));
        }
    }

    private ValidationItem createValidationItem(ValidationItemType type, String field, String message) {
        return new ValidationItem(type, String.format("In field '%s': %s", field, message));
    }

}
