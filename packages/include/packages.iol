include "semver" "semver.iol"

constants {
    VALIDATION_INFO = 0,
    VALIDATION_WARNING = 1,
    VALIDATION_ERROR = 2,
    DEPENDENCY_TYPE_RUNTIME = 0,
    DEPENDENCY_TYPE_INTERFACE = 1
}

type LicenseIdentifier: string
type Author: string {
    .email?: string
    .homepage?: string
}

type Registry: void {
    .name: string
    .location: string
}

type DependencyType: int

type Dependency: void {
    .name: string
    .version: SemVerExpression
    .registry: string
    .type: DependencyType
}

type Package: void {
    .name: string
    .version: SemVer
    .license?: LicenseIdentifier
    .private: bool
    .main?: string
    .authors[1, *]: Author
    .registries[0, *]: Registry
    .dependencies[0, *]: Dependency
}

type ValidationRequest: void {
    .data: any 
}

type ValidationItemType: int

type ValidationItem: void {
    .type: ValidationItemType
    .message: string
}

type ValidationResponse: void {
    .items[0, *]: ValidationItem
    .package?: Package
    .hasErrors: bool
}

interface IPackages {
    RequestResponse:
        validate(ValidationRequest)(ValidationResponse)
}

