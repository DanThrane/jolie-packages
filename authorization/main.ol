include "authorization.iol"
include "time.iol"
include "bcrypt.iol" from "bcrypt"
include "utils.iol" from "jpm-utils"
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
        undef(rights);
        rights << AUTH_DEFAULT_RIGHTS.(resource);
        foreach (right : rights) {
            idx = #t.statement;
            t.statement[idx] = "
                INSERT INTO group_rights
                    (`groupId`, `resource`, `value`)
                VALUES
                    (:groupId, :resource, :value)
            ";
            t.statement[idx].groupId = GroupCreate.out.id;
            t.statement[idx].resource = resource;
            t.statement[idx].value = right
        }
    };
    if (#t.statement > 0) {
        executeTransaction@Database(t)()
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
            gr.value AS value
        FROM
            group_rights gr,
            `group` g
        WHERE
            g.id = gr.groupId AND
            g.groupName = :groupName
    ";

    ns.q.groupName = ns.in.groupName;
    query@Database(ns.q)(ns.result);

    ns.currentRow -> ns.result.row[i];
    for (i = 0, i < #ns.result.row, i++) {
        ns.out.resource.(ns.currentRow.resource) = ns.currentRow.gr_id;
        ns.out.resource.(ns.currentRow.resource).(ns.currentRow.value) =
            true
    }
}

/**
 * @input .token: string
 * @output .resource: Map<String, Set<String>>. Root values contain DB IDs
 */
define UserRightsByToken {
    DatabaseConnect;
    ns -> UserRightsByToken;

    ns.q = "
        SELECT
            gr.id AS gr_id,
            gr.resource AS resource,
            gr.value AS value
        FROM
            group_rights gr,
            `group` g,
            group_member gm,
            `user` u,
            auth_token t
        WHERE
            g.id = gr.groupId AND
            gm.groupId = g.id AND
            gm.userId = u.id AND
            t.userId = u.id AND
            t.token = :token
    ";
    ns.q.token = ns.in.token;

    query@Database(ns.q)(ns.result);

    ns.currentRow -> ns.result.row[i];
    for (i = 0, i < #ns.result.row, i++) {
        ns.out.resource.(ns.currentRow.resource).(ns.currentRow.value) =
            ns.currentRow.gr_id
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

        response = false;
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
        scope (s) {
            install(SQLException =>
                if (s.SQLException.errorCode == 19) {
                    throw(AuthorizationFault, {
                        .type = FAULT_BAD_REQUEST,
                        .message = "Group already exists!"
                    })
                } else {
                    throw(AuthorizationFault, {
                        .type = FAULT_INTERNAL,
                        .message = "Internal server error"
                    })
                }
            );
            groupName = request.groupName;
            GroupRequireNonAuth;

            GroupCreateWithDefaultRights.in.groupName = groupName;
            GroupCreateWithDefaultRights
        }
    }]

    [deleteGroup(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;
        GroupFind;
        undef(group)
    }]

    [changeGroupRights(request)(response) {
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

        change -> request.change[i];
        for (i = 0, i < #request.change, i++) {
            if (change.grant) {
                undef(insertQ);
                insertQ = "
                    INSERT INTO group_rights (groupId, resource, value)
                      SELECT :groupId, :resource, :value
                      EXCEPT
                      SELECT groupId, resource, value
                      FROM group_rights
                      WHERE
                        groupId = :groupId AND
                        resource = :resource AND
                        value = :value
                ";
                insertQ.groupId = group.id;
                insertQ.resource = change.key;
                insertQ.value = change.right;
                batch.statement[#batch.statement] << insertQ
            } else {
                undef(deleteQ);
                deleteQ = "
                    DELETE FROM group_rights
                    WHERE
                        groupId = :groupId AND
                        resource = :resource AND
                        value = :value
                ";
                deleteQ.groupId = group.id;
                deleteQ.resource = change.key;
                deleteQ.value = change.right;

                batch.statement[#batch.statement] << deleteQ
            }
        };
        executeTransaction@Database(batch)()
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
                `id`,`username`
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

        for (i = 0, i < #request.users, i++) {
            if (i > 0) userParamsList += ", ";
            userParamsList += ":user" + i;
            deleteQ.("user" + i) = request.users[i];
            println@Console(request.users[i])()
        };

        replaceAll@StringUtils(deleteQ {
            .regex = "%USER_LIST%",
            .replacement = userParamsList
        })(prepared);
        deleteQ = prepared;

        update@Database(deleteQ)()
    }]

    [getGroupMembers(request)(response) {
        DatabaseConnect;
        q = "
            SELECT
              user.username
            FROM
              'group'
                INNER JOIN group_member ON 'group'.id = group_member.groupId
                INNER JOIN user ON group_member.userId = user.id
            WHERE
              'group'.groupName = :groupName;
        ";
        q.groupName = request.groupName;
        query@Database(q)(sqlResponse);
        for (i = 0, i < #sqlResponse.row, i++) {
            response.members[#response.members] = sqlResponse.row[i].username
        }
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
        currentCheck -> request.check[i];
        for (i = 0, i < #request.check && response, i++) {
            if (!is_defined(resources.(currentCheck.key)
                        .(currentCheck.right))) {
                response = false
            }
        }
    }]

    [hasAnyOfRights(request)(response) {
        UserRightsByToken.in.token = request.token;
        UserRightsByToken;
        resources -> UserRightsByToken.out.resource;

        response = false;
        currentCheck -> request.check[i];
        for (i = 0, i < #request.check && !response, i++) {
            if (is_defined(resources.(currentCheck.key)
                        .(currentCheck.right))) {
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
            DELETE FROM group_rights
            WHERE
                groupId = :groupId AND
                resource = :resource
        ";
        q.groupId = group.id;
        q.resource = request.key;
        update@Database(q)()
    }]
}

