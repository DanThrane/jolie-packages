include "utils.iol" from "jpm-utils"

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
    .sets[1, *]: void {
        .groupName: string
        .change[1, *]: RightsChangeRequest
    }
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

type GroupMembersRequest: void {
    .groupName: string
}

type GroupMembersResponse: void {
    .members[0, *]: string
}

type UserRights: void {
    .username: string
    // matrix a dictionary of type:
    // (groupName) -> (resourceName) -> (right) -> bool
    .matrix: undefined
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

        changeGroupRights(AuthRightsRequest)(void)
            throws AuthorizationFault(ErrorMessage),

        addGroupMembers(AuthGroupMemberRequest)(void)
            throws AuthorizationFault(ErrorMessage),

        removeGroupMembers(AuthGroupMemberRequest)(void)
            throws AuthorizationFault(ErrorMessage),

        hasAnyOfRights(RightsCheckRequest)(bool),

        hasAllOfRights(RightsCheckRequest)(bool),

        revokeRights(RevokeRequest)(void)
            throws AuthorizationFault(ErrorMessage),

        getGroupMembers(GroupMembersRequest)(GroupMembersResponse)
            throws AuthorizationFault(ErrorMessage),

        getRightsByToken(AccessToken)(UserRights)
            throws AuthorizationFault(ErrorMessage),

        groupExists(string)(bool)
            throws AuthorizationFault(ErrorMessage),
}

