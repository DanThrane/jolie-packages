include "authorization.iol"
include "time.iol"
include "bcrypt" "bcrypt.iol"
include "jpm-utils" "utils.iol"
include "db_scripts.iol"
include "config.iol"

execution { sequential }

ext inputPort Authorization {
    Interfaces: IAuthorization
}

/**
 * @input username: string
 * @output groups[0, *]: string
 */
define FindAllGroupsForUsername {
    nextGroup -> groups[#groups];
    foreach (groupName : global.groups) {
        group -> global.groups.(groupName);
        keepRun = true;
        for (i = 0, i < #group.members && keepRun, i++) {
            if (group.members[i] == username) {
                nextGroup = groupName;
                keepRun = false
            }
        }
    }
}

/**
 * @input token: string
 * @output groups[0, *]: string
 */
define FindAllGroupsForToken {
    if (is_defined(request.token)) {
        session -> global.sessions.(request.token);
        if (!is_defined(session)) {
            throw(AuthorizationFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Invalid session"
            })
        };
        username = session.username;
        FindAllGroupsForUsername
    } else {
        groups[0] = "auth.guest"
    }
}

/**
 * @input groupName: string
 * @output group: Group
 */
define GroupFind {
    group -> global.groups.(groupName);
    if (!is_defined(group)) {
        throw(AuthorizationFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "Unknown group"
        })
    }
}

/**
 * @input .username: string
 * @input .password: string
 * @output .token: AccessToken
 * @throws AuthorizationFault if username and password doesn't match
 */
define Auth {
    Auth.invalidError << {
        .type = FAULT_BAD_REQUEST,
        .message = "Invalid username or password"
    };

    UserFindByUsername.in.username = Auth.in.username;
    UserFindByUsername;
    Auth.user -> UserFindByUsername.out.result;

    valueToPrettyString@StringUtils(Auth.user)(pretty);
    println@Console(pretty)();

    if (#Auth.user != 1) {
        throw(AuthorizationFault, Auth.invalidError)
    };

    checkPassword@BCrypt({
        .password = Auth.in.password,
        .hashed = Auth.user.password
    })(Auth.matches);

    if (!Auth.matches) {
        throw(AuthorizationFault, Auth.invalidError)
    };

    AuthTokenCreate.in.token = new;
    AuthTokenCreate.in.userId = Auth.user.id;
    getCurrentTimeMillis@Time()(AuthTokenCreate.in.timestamp);
    AuthTokenCreate;

    Auth.out.token = AuthTokenCreate.in.token
}

/**
 * @input groupName: string
 */
define GroupRequireNonAuth {
    startsWith@StringUtils(groupName { .prefix = "auth." })(isAuthGroup);
    if (isAuthGroup) {
        throw(AuthorizationFault, {
            .type = FAULT_BAD_REQUEST,
            .message = "auth.* groups cannot be changed externally"
        })
    };
    undef(isAuthGroup)
}

/**
 * @input .groupName: string
 * @input .userIds[*]: long
 * @output .groupId: long
 */
define GroupCreateWithDefaultRights {
    ns -> GroupCreateWithDefaultRights;

    // Create group for user
    GroupCreate.in.groupName = ns.in.groupName;
    GroupCreate;

    // Add users to group
    for (i = 0, i < #ns.in.userIds, i++) {
        GroupMemberCreate.in.groupId = GroupCreate.out.id;
        GroupMemberCreate.in.userId = ns.in.userIds[i];
        GroupMemberCreate
    };

    // Grant default rights to group
    foreach (resource : AUTH_DEFAULT_RIGHTS) {
        GroupRightsCreate.in.groupId = GroupCreate.out.id;
        GroupRightsCreate.in.resource = resource;
        GroupRightsCreate;

        rights << AUTH_DEFAULT_RIGHTS.(resource);
        foreach (right : rights) {
            idx = #t.statement;
            t.statement[idx] = "INSERT INTO `resource_right`
                (`group_rightsId`, `value`)
                VALUES (:gr, :value)";
            t.statement[idx].gr = GroupRightsCreate.out.id;
            t.statement[idx].value = right
        };
        executeTransaction@Database(t)();

        undef(rights);
        undef(t)
    };

    ns.out.groupId = GroupCreate.out.id
}

/**
 * @input .groupName: string
 * @output .resource: Map<String, Set<String>>
 */
define GroupRightsByGroupName {
    DatabaseConnect;
    ns -> GroupRightsByGroupName;

    ns.q = "
        SELECT
            gr.id AS gr_id,
            gr.resource AS resource,
            rr.id AS rr_id,
            rr.value AS value
        FROM
            group_rights gr,
            resource_right rr,
            group g
        WHERE
            g.id = gr.groupId AND
            gr.id = rr.group_rightsId AND
            g.groupName = :groupName
    ";

    ns.q.groupName = ns.in.groupName;
    query@Database(ns.q)(ns.result);

    ns.currentRow -> ns.result.row[i];
    for (i = 0, i < #ns.result.row, i++) {
        ns.out.resource.(ns.currentRow.resource) = ns.currentRow.gr_id;
        ns.out.resource.(ns.currentRow.resource).(ns.currentRow.value) =
            ns.currentRow.rr_id
    }
}

/**
 * @input .token: string
 * @output .resource: Map<String, Set<String>>. Root values contain DB IDs
 */
define UserRightsByToken {
    DatabaseConnect;
    ns -> UserRightsByUsername;

    ns.q = "
        SELECT
            gr.id AS gr_id,
            gr.resource AS resource,
            rr.id AS rr_id,
            rr.value AS value
        FROM
            group_rights gr,
            resource_right rr,
            group g,
            group_member gm,
            `user` u,
            auth_token t
        WHERE
            g.id = gr.groupId AND
            gr.id = rr.group_rightsId AND
            gm.groupId = g.id AND
            gm.userId = u.id AND
            t.userId = u.id AND
            t.token = :token
    ";
    ns.q.token = ns.in.token;

    query@Database(ns.q)(ns.result);

    ns.currentRow -> ns.result.row[i];
    for (i = 0, i < #ns.result.row, i++) {
        ns.out.resource.(ns.currentRow.resource) = ns.currentRow.gr_id;
        ns.out.resource.(ns.currentRow.resource).(ns.currentRow.value) =
            ns.currentRow.rr_id;
    }
}

init {
    install(AuthorizationFault => nullProcess);

    DatabaseInit
}

main {
    [debug()() {
        // TODO This should obviously not be left in.
        value -> global.sessions; DebugPrintValue;
        value -> global.groups; DebugPrintValue
    }]

    [register(request)(Auth.out.token) {
        DatabaseConnect;

        // Create user
        scope (userCreateScope) {
            install(SQLException =>
                throw(AuthorizationFault, {
                    .type = FAULT_BAD_REQUEST,
                    .message = "Username is already taken!"
                })
            );
            UserCreate.in.username = request.username;
            hashPassword@BCrypt(request.password)(UserCreate.in.password);
            UserCreate
        };

        // Authenticate with system
        Auth.in.username = request.username;
        Auth.in.password = request.password;
        Auth
    }]

    [authenticate(request)(Auth.out.token) {
        Auth.in.username = request.username;
        Auth.in.password = request.password;
        Auth
    }]

    [invalidate(token)(response) {
        AuthTokenDeleteByToken.in.token = token;
        AuthTokenDeleteByToken
    }]

    [validate(request)(response) {
        AuthTokenFindByToken.in.token = request.token;
        AuthTokenFindByToken;
        token -> AuthTokenFindByToken.out.result;

        if (#token == 1) {
            if (is_defined(request.maxAge)) {
                getCurrentTimeMillis@Time()(now);
                age = now - token.timestamp;
                response = age <= request.maxAge
            } else {
                response = true
            };

            if (response) {
                UserFindById.in.id = token.userId;
                UserFindById;
                user -> UserFindById.out.result;

                response.username = user.username
            }
        }
    }]

    [createGroup(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;

        GroupCreateWithDefaultRights.in.groupName = groupName;
        GroupCreateWithDefaultRights
    }]

    [deleteGroup(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;
        GroupFind;
        undef(group)
    }]

    [changeGroupRights(request)(response) {
        // TODO Remember to re-use group_rights
        groupName = request.groupName;
        GroupRequireNonAuth;

        GroupFindByGroupName.in.groupName = groupName;
        GroupFindByGroupName;
        group -> GroupFindByGroupName.out.result;

        if (#group == 0) {
            throw(AuthorizationFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unknown group!"
            })
        };

        GroupRightsByGroupName.in.groupName = groupName;
        GroupRightsByGroupName;
        resources -> GroupRightsByGroupName.out.resource;

        // Pre-process the data to figure out the following:
        //     grToCreate: Set<String>
        //     rrToCreate: Map<String, Set<String>e
        //     rrToDelete[*]: long

        change -> request.change[i];
        for (i = 0, i < #request.change, i++) {
            if (!is_defined(resource.(change.key))) {
                grToCreate.(change.key) = true
            }
            hasRight = is_defined(resources.(change.key).(change.right);

            if (change.grant) {
                if (!hasRight) {
                    rrToCreate.(change.key).(change.right) = true
                }
            } else {
                if (hasRight) {
                    rrToDelete[#rrToDelete] = resources.
                        (change.key).(change.right);
                }
            }
        };

        // Perform updates
        stmt -> t.statement;

        // Create all group_rights that are needed
        foreach (gr : grToCreate) {
            
        }
    }]

    [addGroupMembers(request)(response) {
        DatabaseConnect;

        groupName = request.groupName;
        GroupRequireNonAuth;

        GroupFindByGroupName.in.groupName = groupName;
        GroupFindByGroupName;
        group -> GroupFindByGroupName.out.result;

        if (#group == 0) {
            throw(AuthorizationFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Group does not exist!"
            })
        };

        userQ = "
            SELECT
                `id`,
                `username`
            FROM
                `user`
            WHERE
                `username` IN (";

        for (i = 0, i < #request.users, i++) {
            if (i > 0) userQ += ", ";
            userQ += ":user" + i;
            userQ.("user" + i) = request.users[i]
        };
        userQ += ")";

        valueToPrettyString@StringUtils(userQ)(pretty);
        println@Console(pretty)();
        query@Database(userQ)(resultUsers);

        if (#resultUsers.row != #request.users) {
            println@Console("Could not find all users to add!")();
            println@Console("Expected to find " + #request.users + ", " +
                    "but only found " + #resultUsers.row)()
        };

        for (i = 0, i < #resultUsers.row, i++) {
            idx = #t.statement;
            t.statement[idx] = "INSERT INTO `group_member`
                (`userId`, `groupId`) VALUES (:userId, :groupId);";
            t.statement[idx].userId = resultUsers.row[i].id;
            t.statement[idx].groupId = group.id
        };

        executeTransaction@Database(t)()
    }]

    [removeGroupMembers(request)(response) {
        // TODO Never tested
        DatabaseConnect;

        groupName = request.groupName;
        GroupRequireNonAuth;

        GroupFindByGroupName.in.groupName = groupName;
        GroupFindByGroupName;
        group -> GroupFindByGroupName.out.result;

        deleteQ = "
            DELETE FROM group_member WHERE userId IN (
                SELECT id FROM `user` WHERE `username` IN (%USER_LIST%)
            );
        ";

        for (i = 0, i <= #request.users, i++) {
            if (i > 0) userParamsList = ", ";
            usersParamsList += ":user" + i;
            deleteQ.(":user" + i) = request.users[i]
        };

        replaceAll@StringUtils(deleteQ {
            .regex = "%USER_LIST%",
            .replacement = userParamList
        })(deleteQ);

        update@Database(deleteQ)()
    }]

    [getGroup(request)(response) {
        nullProcess // TODO Do we need this?
    }]

    [listGroupsByUser(request)(response) {
        nullProcess // TODO Do we need this?
    }]

    [hasAllOfRights(request)(response) {
        UserRightsByToken.in.token = request.token;
        UserRightsByToken;
        resources -> UserRightsByToken.out.resource;

        response = true;
        currentCheck = request.check[i];
        for (i = 0, i < #request.check && response, i++) {
            if (!is_defined(resources.(key).(right))) {
                response = false
            }
        }
    }]

    [hasAnyOfRights(request)(response) {
        UserRightsByToken.in.token = request.token;
        UserRightsByToken;
        resources -> UserRightsByToken.out.resource;

        response = false;
        currentCheck = request.check[i];
        for (i = 0, i < #request.check && !response, i++) {
            if (is_defined(resources.(key).(right))) {
                response = true
            }
        }
    }]

    [revokeRights(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;

        GroupFindByGroupName.in.groupName = groupName;
        GroupFindByGroupName;
        group -> GroupFindByGroupName.out.result;

        if (#group == 0) {
            throw(AuthorizationFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Unknown group"
            })
        };

        q = "
            DELETE FROM resource_rights WHERE group_rightsId IN (
                SELECT gr.id
                FROM
                    group g,
                    group_rights gr
                WHERE
                    g.id = gr.groupId AND
                    gr.resource = :resource
            );
        ";
        q.resource = request.key;
        update@Database(q)()
    }]
}

