include "file.iol"
include "packages.iol"
include "string_utils.iol"
include "console.iol"
include "semver" "semver.iol"

execution { concurrent }

inputPort Packages {
    Location: "socket://localhost:8888"
    Protocol: sodep
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
    TYPE_DOUBLE = 4,
    VALIDATION_INFO = 0,
    VALIDATION_WARNING = 1,
    VALIDATION_ERROR = 2,
}

embedded {
	Java:
		"dk.thrane.jolie.packages.PackageService" in ValidationUtil
}

init
{
	getFileSeparator@File()(FILE_SEP)
}

main
{
	[validate(request)(response) {
		// TODO Exception handlers
		scope (parsing) {
			nextItem -> response.items[#response.items];

			install(IOException => 
				println@Console("Parsing error")();
				response = "BAD"
			);
			install(InvalidVersion =>
				println@Console("Bad version")();
				response = "BAD"
			);


			// Parse package file
			fileName = request.location + FILE_SEP + "package.json";
			readFile@File({
				.filename = fileName,
				.format = "json"
			})(file);

			// Validate name
			validateName@ValidationUtil(file)(response);

			// Validate version
			validationRequest.value -> file;
			validationRequest.child = "version";
			validationRequest.type = TYPE_STRING;
			requireChildOfType@ValidationUtil(validationRequest)(hasVersion);

			if (hasVersion) {
				parseVersion@SemVer(file.version)(resp)
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
			optionalChildOfType@ValidationUtil(validationRequest)(validLicenseType);

			if (!validLicenseType) {
				nextItem << {
					.type = VALIDATION_ERROR,
					.message = "'license' field must be of type string"
				}
			};

			if (is_defined(file.license)) {
				isValidLicenseIdentifier@ValidationUtil(file.license)(validLicenseIdentifier);
				if (!validLicenseIdentifier) {
					nextItem << {
						.type = VALIDATION_ERROR,
						.message = "'" + file.license + "' is not a valid license identifier. See " + 
							"https://spdx.org/licenses/ for a complete list of valid identifiers" 
					}
				}
			};

			// Validate private
			validationRequest.value -> file;
			validationRequest.child = "private";
			validationRequest.type  = TYPE_BOOL;
			optionalChildOfType@ValidationUtil(validationRequest)(validPrivateType);

			if (!validPrivateType) {
				nextItem << {
					.type = VALIDATION_ERROR,
					.message = "'private' field must be of type bool"
				}
			};

			// Validate main
			validationRequest.value -> file;
			validationRequest.child = "main";
			validationRequest.type  = TYPE_STRING;
			optionalChildOfType@ValidationUtil(validationRequest)(validMainType);

			if (!validMainType) {
				nextItem << {
					.type = VALIDATION_ERROR,
					.message = "'main' field must be of type string"
				}
			};

			// Validate authors
			validateAuthors@ValidationUtil(file)(authorsResp);
			for (i = 0, i < #authorsResp.items, i++) {
				nextItem << authorsResp.items[i]
			};

			// Validate registries
			knownRegistries.public.location = "?"; // Don't really need to know where, we just need an entry for public
			if (is_defined(file.registries)) {
				registry -> file.registries[i];
				for (i = 0, i < #file.registries, i++) {
					// registry.name
					validationRequest.value -> registry;
					validationRequest.child = "name";
					validationRequest.type = TYPE_STRING;
					requireChildOfType@ValidationUtil(validationRequest)(validNameType);

					if (!validNameType) {
						nextItem << {
							.type = VALIDATION_ERROR,
							.message = "'registries[" + i + "].name' must be of type string" 
						}
					};

					// registry.location
					validationRequest.value -> registry;
					validationRequest.child = "location";
					validationRequest.type = TYPE_STRING;
					requireChildOfType@ValidationUtil(validationRequest)(validLocationType);

					if (!validLocationType) {
						nextItem << {
							.type = VALIDATION_ERROR,
							.message = "'registries[" + i + "].location' must be of type string"
						}
					} else {
						// TODO not sure the constraints put on URIs are currently valid
						validateURI@ValidationUtil(registry.location)(validLocation);
						if (!validLocation) {
							nextItem << {
								.type = VALIDATION_ERROR,
								.message = "'registries[" + i + "].location' must be a valid URI"
							}
						}
					};

					knownRegistries.(registry.name).location = registry.location
				}
			};

			// Validate dependencies
			if (is_defined(file.dependencies)) {
				dependency -> file.dependencies[i];
				for (i = 0, i < #file.dependencies, i++) {
					// Validate dependencies.name
					validationRequest.value -> dependency;
					validationRequest.child = "name";
					validationRequest.type = TYPE_STRING;
					requireChildOfType@ValidationUtil(validationRequest)(validNameType);

					if (!validNameType) {
						nextItem << {
							.type = VALIDATION_ERROR,
							.message = "'dependencies[" + i + "].name' must be of type string"
						}
					};

					// Validate dependencies.version
					validationRequest.value -> dependency;
					validationRequest.child = "version";
					validationRequest.type = TYPE_STRING;
					requireChildOfType@ValidationUtil(validationRequest)(validVersionType);

					if (!validVersionType) {
						nextItem << {
							.type = VALIDATION_ERROR,
							.message = "'dependencies[" + i + "].version' must be of type string"
						}
					} else {
						validatePartial@SemVer(dependency.version)(validPartial);
						if (!validPartial) {
							nextItem << {
								.type = VALIDATION_ERROR,
								.message = "'dependencies[" + i + "].version' must be a valid version expression"
							}
						}
					};

					// Validate dependencies.registry
					validationRequest.value -> dependency;
					validationRequest.child = "registry";
					validationRequest.type = TYPE_STRING;
					optionalChildOfType@ValidationUtil(validationRequest)(validRegistryType);

					if (!validRegistryType) {
						nextItem << {
							.type = VALIDATION_ERROR,
							.message = "'dependencies[" + i + "].registry' must be of type string"
						}
					} else {
						if (!is_defined(knownRegistries.(dependency.registry))) {
							nextItem << {
								.type = VALIDATION_ERROR,
								.message = "'dependencies[" + i +"].registry' contains an unknown registry '" + 
									dependency.registry + "'"
							}
						}
					}
				}
			}
		}
	}]

}
