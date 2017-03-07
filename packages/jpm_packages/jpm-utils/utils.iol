include "string_utils.iol"
include "console.iol"

/**
 * @input value: undefined
 */
define DebugPrintValue {
    valueToPrettyString@StringUtils(value)(prettyValue);
    println@Console(prettyValue)();
    undef(prettyValue)
}

constants {
    FAULT_BAD_REQUEST = 400,
    FAULT_NOT_FOUND = 404,
    FAULT_INTERNAL = 500
}

type ErrorMessage: void {
    .type: int
    .message: string
    .details?: undefined
}
