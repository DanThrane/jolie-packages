# Jolie Style Guide

This is an attempt at a Jolie style guide and best practices.

## Naming

When using services that provide more than one type of resource, the resource
type should be included in the name.

Typical CRUD-like operations should be named in the following manner:

  - `getType[With...]`
  - `insertType[With...]`
  - `updateType[With...]`
  - `existsType[With...]`
  - `listType[With...]`

Examples:

  - `getPackageWithNameAndVersion`
  - `getPackageWithName`
  - `getPackage` (Using some unique ID)
  - `insertPackage`
  - `updatePackage`
  - `existsPackageWithNameAndVersion`

The fields used in requests that contains a `With` section, should match the
operation name. For example `existsPackageWithNameAndVersion` should have a
request type as follows:

```
type Request: void {
    .name: string
    .version: SemVer
}
```

### Request and Response Types

The names of these types should be prefixed with a common prefix for the entire
service. This prefix doesn't have to match the package name, but should be
similar to the actual name. Generic types that are only used for operations
should also be suffixed with either `Request` or `Response`.

Responses returning a typical listing (i.e. `listType[With...]` should return
have the following response type:

```
type PrefixListType[With...]Response : void {
    .result[0, *]: Type
}
```

## Embedded Services

Typical embedded Java services should provide two different include files,
those following this nameing scheme:

  - `name_interface.iol`
  - `name.iol`

Including `name.iol` should give us an output port with the embedding already
performed. The `name_interface.iol` file should only contain interfaces and
types, no embedding should be created. This allows for other services to
use the types exposed by another services, without having to depend on the
Java service.
