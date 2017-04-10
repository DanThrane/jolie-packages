include "file.iol"
include "packages.iol"
include "string_utils.iol"
include "console.iol"
include "json_utils.iol"
include "semver.iol" from "semver"
include "utils.iol" from "jpm-utils"

execution { concurrent }

ext inputPort Packages {
    Interfaces: IPackages
}

interface IValidationUtil {
    RequestResponse:
        validateName(undefined)(undefined),
        requireChild(undefined)(bool),
        requireChildOfType(undefined)(bool),
        optionalChildOfType(undefined)(bool),
        isValidLicenseIdentifier(string)(bool),
        validateAuthors(undefined)(undefined),
        validateURI(string)(bool)
}

outputPort ValidationUtil {
    Interfaces: IValidationUtil
}

constants {
    TYPE_STRING = 0,
    TYPE_BOOL = 1,
    TYPE_INT = 2,
    TYPE_LONG = 3,
    TYPE_DOUBLE = 4
}

embedded {
    Java:
        "dk.thrane.jolie.packages.PackageService" in ValidationUtil
}

/**
 * @input report: ValidationResponse
 * @output hasErrors: bool
 */
define ValidationCheckForErrors {
    hasErrors = false;
    // We need to save the old index and restore it later.
    // Otherwise we will have bugs. Even worse, we can't use oldI everywhere
    // if we nest them :-)
    oldI = i;
    for (i = 0, !hasErrors && i < #report.items, i++) {
        if (report.items[i].type == VALIDATION_ERROR) {
            hasErrors = true
        }
    };
    i = oldI;
    undef(oldI)
}

define ValidateDependencies {
    dependency -> dependencies[i];
    for (i = 0, i < #dependencies, i++) {
        // Validate dependencies.name
        validationRequest.value -> dependency;
        validationRequest.child = "name";
        validationRequest.type = TYPE_STRING;
        requireChildOfType@ValidationUtil(validationRequest)
            (validNameType);

        if (!validNameType) {
            nextItem << {
                .type = VALIDATION_ERROR,
                    .message = "'" + name + "[" + i +
                        "].name' must be of type string"
            }
        } else {
            packageDependency.name = dependency.name
        };

        // Validate dependencies.version
        validationRequest.value -> dependency;
        validationRequest.child = "version";
        validationRequest.type = TYPE_STRING;
        requireChildOfType@ValidationUtil(validationRequest)
            (validVersionType);

        if (!validVersionType) {
            nextItem << {
                .type = VALIDATION_ERROR,
                    .message = "'" + name + "[" + i +
                        "].version' must be of type string"
            }
        } else {
            validatePartial@SemVer(dependency.version)(validPartial);
            if (!validPartial) {
                nextItem << {
                    .type = VALIDATION_ERROR,
                        .message = "'" + name + "[" + i +
                            "].version' must be a valid version expression"
                }
            } else {
                packageDependency.version = dependency.version
            }
        };

        // Validate dependencies.registry
        validationRequest.value -> dependency;
        validationRequest.child = "registry";
        validationRequest.type = TYPE_STRING;
        optionalChildOfType@ValidationUtil(validationRequest)
            (validRegistryType);

        if (!is_defined(dependency.registry)) {
            packageDependency.registry = "public"
        } else {
            if (!validRegistryType) {
                nextItem << {
                    .type = VALIDATION_ERROR,
                        .message = "'" + name + "[" + i +
                            "].registry' must be of type string"
                }
            } else {
                if (!is_defined(knownRegistries.
                            (dependency.registry))) {
                    nextItem << {
                        .type = VALIDATION_ERROR,
                            .message = "'" + name + "[" + i +
                                "].registry' contains an unknown " +
                                "registry '" + dependency.registry + "'"
                    }
                } else {
                    packageDependency.registry = dependency.registry
                }
            }
        };

        dependencyOutput[#dependencyOutput] << packageDependency
    }
}

init
{
    getFileSeparator@File()(FILE_SEP)
}

main
{
    [validate(request)(response) {
        // TODO FIXME We shouldn't allow multiple dependencies with the same
        // name, even if they are from different registries

        nextItem -> response.items[#response.items];

        scope (parsing) {
            install(default =>
                nextItem << {
                    .type = VALIDATION_ERROR,
                    .message = "Error parsing package.json"
                }
            );

            getJsonValue@JsonUtils(request.data)(file)
        };

        report -> response;
        ValidationCheckForErrors;
        if (!hasErrors) {
            // Validate name
            validateName@ValidationUtil(file)(response);
            packageBuilder.name = file.name;

            // Validate description
            validationRequest.value -> file;
            validationRequest.child = "description";
            validationRequest.type = TYPE_STRING;
            optionalChildOfType@ValidationUtil(validationRequest)
                (hasDescription);

            if (hasDescription) {
                if (is_defined(file.description)) {
                    packageBuilder.description = file.description
                }
            } else {
                nextItem << {
                    .type = VALIDATION_ERROR,
                    .message = "'description' field must be of type string"
                }
            };

            // Validate version
            validationRequest.value -> file;
            validationRequest.child = "version";
            validationRequest.type = TYPE_STRING;
            requireChildOfType@ValidationUtil(validationRequest)(hasVersion);

            if (hasVersion) {
                validateVersion@SemVer(file.version)(validVersion);
                if (!validVersion) {
                    nextItem << {
                        .type = VALIDATION_ERROR,
                        .message = "'version' is not a valid semver"
                    }
                } else {
                    parseVersion@SemVer(file.version)(packageBuilder.version)
                }
            } else {
                nextItem << {
                    .type = VALIDATION_ERROR,
                    .message = "'version' field required with type string"
                }
            };

            // Validate license
            validationRequest.value -> file;
            validationRequest.child = "license";
            validationRequest.type = TYPE_STRING;
            optionalChildOfType@ValidationUtil(validationRequest)
                (validLicenseType);

            if (!validLicenseType) {
                nextItem << {
                    .type = VALIDATION_ERROR,
                    .message = "'license' field must be of type string"
                }
            };

            if (is_defined(file.license)) {
                isValidLicenseIdentifier@ValidationUtil(file.license)
                    (validLicenseIdentifier);
                if (!validLicenseIdentifier) {
                    nextItem << {
                        .type = VALIDATION_ERROR,
                        .message = "'" + file.license +
                            "' is not a valid license identifier. See " +
                            "https://spdx.org/licenses/ for a complete list " +
                            "of valid identifiers"
                    }
                } else {
                    packageBuilder.license = file.license
                }
            };

            // Validate private
            validationRequest.value -> file;
            validationRequest.child = "private";
            validationRequest.type  = TYPE_BOOL;
            optionalChildOfType@ValidationUtil(validationRequest)
                (validPrivateType);

            if (!validPrivateType) {
                nextItem << {
                    .type = VALIDATION_ERROR,
                    .message = "'private' field must be of type bool"
                }
            } else {
                if (is_defined(file.private)) {
                    packageBuilder.private = file.private
                } else {
                    packageBuilder.private = true
                }
            };

            // Validate main
            validationRequest.value -> file;
            validationRequest.child = "main";
            validationRequest.type  = TYPE_STRING;
            optionalChildOfType@ValidationUtil(validationRequest)
                (validMainType);

            if (!validMainType) {
                nextItem << {
                    .type = VALIDATION_ERROR,
                    .message = "'main' field must be of type string"
                }
            };

            if (is_defined(file.main)) {
                packageBuilder.main = file.main
            };

            // Validate authors
            if (!is_defined(file.authors)) {
                nextItem << {
                    .type = VALIDATION_ERROR,
                    .message = "'authors' field is not optional"
                }
            };
            validateAuthors@ValidationUtil(file)(authorsResp);

            for (i = 0, i < #authorsResp.items, i++) {
                nextItem << authorsResp.items[i]
            };
            if (is_defined(authorsResp.authors)) {
                for (i = 0, i < #authorsResp.authors, i++) {
                    packageBuilder.authors[i] << authorsResp.authors[i]
                }
            };

            // Validate events
            if (is_defined(file.events)) {
                foreach (eventName : file.events) {
                    if (!is_string(eventName)) {
                        nextItem << {
                            .type = VALIDATION_ERROR,
                            .message = "events." + eventName + " key must " +
                                "be a string!"
                        }
                    };

                    if (!is_string(file.events.(eventName))) {
                        nextItem << {
                            .type = VALIDATION_ERROR,
                            .message = "events." + eventName + " value must " +
                                "be a string!"
                        }
                    };

                    packageBuilder.events.(eventName) = file.events.(eventName)
                }
            };

            // Validate registries

            // Don't really need to know where, we just need an entry for
            // public
            knownRegistries.public.location = "?";

            registry -> file.registries[i];
            for (i = 0, i < #file.registries, i++) {
                // registry.name
                validationRequest.value -> registry;
                validationRequest.child = "name";
                validationRequest.type = TYPE_STRING;
                requireChildOfType@ValidationUtil(validationRequest)
                    (validNameType);

                if (!validNameType) {
                    nextItem << {
                        .type = VALIDATION_ERROR,
                        .message = "'registries[" + i +
                            "].name' must be of type string"
                    }
                };

                // registry.location
                validationRequest.value -> registry;
                validationRequest.child = "location";
                validationRequest.type = TYPE_STRING;
                requireChildOfType@ValidationUtil(validationRequest)
                    (validLocationType);

                if (!validLocationType) {
                    nextItem << {
                        .type = VALIDATION_ERROR,
                        .message = "'registries[" + i +
                            "].location' must be of type string"
                    }
                } else {
                    validateURI@ValidationUtil(registry.location)
                        (validLocation);
                    if (!validLocation) {
                        nextItem << {
                            .type = VALIDATION_ERROR,
                            .message = "'registries[" + i +
                                "].location' must be a valid URI"
                        }
                    }
                };

                if (registry.name == "public") {
                    nextItem << {
                        .type = VALIDATION_ERROR,
                        .message = "'registries[" + i +
                            "].name' cannot be 'public'!"
                    }
                };

                if (is_defined(knownRegistries.(registry.name))) {
                    nextItem << {
                        .type = VALIDATION_WARNING,
                        .message = "'registries[" + i +
                            "].name' is overriding a previous registry " +
                            "definition!"
                    }
                };

                knownRegistries.(registry.name).location = registry.location;

                packageRegistry.name = registry.name;
                packageRegistry.location = registry.location;
                packageBuilder.registries[#packageBuilder.registries] <<
                    packageRegistry
            };

            // Validate dependencies
            dependencyOutput -> packageBuilder.dependencies;
            dependencies -> file.dependencies;
            name = "dependencies";
            ValidateDependencies;

            dependencyOutput -> packageBuilder.interfaceDependencies;
            dependencies -> file.interfaceDependencies;
            name = "interfaceDependencies";
            ValidateDependencies;

            // Append processed package if we have no errors
            ValidationCheckForErrors;
            if (!hasErrors) {
                response.package -> packageBuilder
            };
            response.hasErrors = hasErrors
        } else {
            response.hasErrors = true
        }
    }]
}

