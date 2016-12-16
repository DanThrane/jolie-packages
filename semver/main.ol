include "console.iol"
include "string_utils.iol"
include "semver.iol"

execution { concurrent }

constants {
    LOCATION = "local"
}

inputPort SemVer {
    Location: "socket://localhost:12345"
    Protocol: sodep
    Interfaces: ISemanticVersion
}

inputPort Local {
    Location: LOCATION
    Interfaces: ISemanticVersion
}

constants {
    VERSION_REGEX = "(\\d+)\\.(\\d+)\\.(\\d+)(-.+)?",
    PARTIAL_REGEX = "([xX*]|(\\d+))((\\.([xX*]|(\\d+)))?(\\.([xX*]|(\\d+)))?)"
}

define checkIfGroupIsBlank {
    groupIsBlank = group == "x" || group == "X" || group == "*" || group == ""
}

define groupToValue {
    checkIfGroupIsBlank;
    if (groupIsBlank) {
        value = -1
    } else {
        value = int(group)
    }
}

define checkForComparatorIfNotFound {
    if (comparatorId == 0) {
        startsWith@StringUtils(trimmedVersion { 
            .prefix = comparator 
        })(hasComparator);
        
        if (hasComparator) {
            comparatorId = comparatorName;
            length@StringUtils(comparator)(comparatorLength);
            length@StringUtils(trimmedVersion)(versionStringLength);
            substring@StringUtils(trimmedVersion { 
                .begin = comparatorLength, 
                .end = versionStringLength
            })(trimmedVersion)
        };

        undef(hasComparator)
    }
}

define parsePartial {
    match@StringUtils(input { .regex = PARTIAL_REGEX })(matched);
        
    if (matched == 1) {
        group = matched.group[1];
        groupToValue;
        output.major = value;

        group = matched.group[5];
        groupToValue;
        output.minor = value;

        group = matched.group[8];
        groupToValue;
        output.patch = value
    } else {
        throw(InvalidInputFault)
    }
}

define parseRange {
    trim@StringUtils(req)(trimmedVersion);
    comparatorId = COMPARATOR_EQUAL;

    comparator = ">="; 
    comparatorName = COMPARATOR_GREATER_EQUAL;
    checkForComparatorIfNotFound;

    comparator = ">";
    comparatorName = COMPARATOR_GREATER;
    checkForComparatorIfNotFound;

    comparator = "<=";
    comparatorName = COMPARATOR_LESSER_EQUAL;
    checkForComparatorIfNotFound;

    comparator = "<"; 
    comparatorName = COMPARATOR_LESSER;
    checkForComparatorIfNotFound;

    comparator = "=";
    comparatorName = COMPARATOR_EQUAL;
    checkForComparatorIfNotFound;

    input = trimmedVersion;
    parsePartial;
    res.partial << output;

    res.comparator = comparatorId
}

main
{
    [parseVersion(req)(res) {
        match@StringUtils(req { .regex = VERSION_REGEX })(matched);

        if (matched == 1) {
            res.major = int(matched.group[1]);
            res.minor = int(matched.group[2]);
            res.patch = int(matched.group[3]);

            length@StringUtils(matched.group[4])(labelLength);
            if (labelLength > 0) {
                substring@StringUtils(matched.group[4] { 
                    .begin = 1, 
                    .end = labelLength 
                })(res.label)
            }
        } else {
            throw(InvalidInputFault)
        }
    }]

    [parsePartial(req)(res) {
        input = req;
        parsePartial;
        res -> output
    }]

    [parseRange(req)(res) {
        
    }]

    [parseRangeSet(req)(res) {
        nullProcess
    }]

    [compareVersions(req)(res) {
        nullProcess
    }]

    [versionSatisfiesRange(req)(res) {
        nullProcess
    }]
}
