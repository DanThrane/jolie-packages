/// AUTO-GENERATED CODE - DO NOT MODIFY
type User: void {
    .username: string
    .password: string
}

type Group: void {
    .groupName: string
}

type GroupMember: void {
    .user: User
    .group: Group
}

type GroupRights: void {
    .group: Group
    .resource: string
    .value: string
}

type AuthToken: void {
    .token: string
    .timestamp: long
    .user: User
}

