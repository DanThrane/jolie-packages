include "jpm-utils" "utils.iol"

type AccessToken: string
type AuthAuthorizationRequest: void {
    .username: string
    .password: string
}

type AuthValidationRequest: void {
    .token: AccessToken
    .maxAge?: long
}

type AuthValidationResponse: bool {
    .username?: string
}

type AuthRegistrationRequest: void {
    .username: string
    .password: string
}

type AuthGroupRequest: void {
    .groupName: string
}

type RightsChangeRequest: void {
    .key: string
    .right: string
    .grant: bool
}

type AuthRightsRequest: void {
    .groupName: string
    .change[1, *]: RightsChangeRequest
}

type AuthGroupMemberRequest: void {
    .groupName: string
    .users[1, *]: string
}

type AuthListGroupsRequest: void {
    .username: string
}

type AuthListGroupsResponse: void {
    .groups[0, *]: string
}

type RightsCheckRequest: void {
    .token?: AccessToken
    .check[1, *]: void {
        .key: string
        .right: string
    }
}

type AuthGroupRequest: void {
    .groupName: string
}

type Group: void {
    .name: string
    .members[0, *]: string
    .objects[0, *]: void {
        .key: string
        .rights[0, *]: string
    }
}

type RevokeRequest: void {
    .groupName: string
    .key: string
}

interface IAuthorization {
    RequestResponse:
        register(AuthRegistrationRequest)(AccessToken)
            throws AuthorizationFault(ErrorMessage),
        authenticate(AuthAuthorizationRequest)(AccessToken) 
            throws AuthorizationFault(ErrorMessage),
        invalidate(AccessToken)(void),
        validate(AuthValidationRequest)(AuthValidationResponse),
        createGroup(AuthGroupRequest)(void)
            throws AuthorizationFault(ErrorMessage),
        deleteGroup(AuthGroupRequest)(void)
            throws AuthorizationFault(ErrorMessage),
        changeGroupRights(AuthRightsRequest)(void)
            throws AuthorizationFault(ErrorMessage),
        addGroupMembers(AuthGroupMemberRequest)(void)
            throws AuthorizationFault(ErrorMessage),
        removeGroupMembers(AuthGroupMemberRequest)(void)
            throws AuthorizationFault(ErrorMessage),
        getGroup(AuthGroupRequest)(Group)
            throws AuthorizationFault(ErrorMessage),
        listGroupsByUser(AuthListGroupsRequest)(AuthListGroupsResponse)
            throws AuthorizationFault(ErrorMessage),
        hasAnyOfRights(RightsCheckRequest)(bool),
        hasAllOfRights(RightsCheckRequest)(bool),
        revokeRights(RevokeRequest)(void)
            throws AuthorizationFault(ErrorMessage),
        debug(void)(void)
}
