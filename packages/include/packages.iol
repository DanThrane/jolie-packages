type ValidationRequest: void {
	.location: string
}
type ValidationResponse: undefined

interface IPackages {
	RequestResponse:
		validate(ValidationRequest)(ValidationResponse)
}