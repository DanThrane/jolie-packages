include "semver" "semver.iol"

type LicenseIdentifier: string
type Author: string {
	.email?: string
	.homepage?: string
}

type Registry: void {
	.name: string
	.location: string
}

type Dependency: void {
	.name: string
	.version: SemVerExpression
	.registry: string
}

type Package: void {
	.name: string
	.version: SemVer
	.license: LicenseIdentifier
	.private: bool
	.main?: string
	.authors[1, *]: Author
	.registries[0, *]: Registry
	.dependencies[0, *]: Dependency
}

type ValidationRequest: void {
	.location: string
}

type ValidationItemType: int

type ValidationItem: void {
	.type: ValidationItemType
	.message: string
}

type ValidationResponse: void {
	.items[0, *]: ValidationItem
	.package?: Package
}

interface IPackages {
	RequestResponse:
		validate(ValidationRequest)(ValidationResponse)
}