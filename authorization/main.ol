include "authorization.iol"
include "time.iol"
include "bcrypt" "bcrypt.iol"
include "jpm-utils" "utils.iol"
include "db_scripts.iol"

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

init {
    install(AuthorizationFault => nullProcess);

    DatabaseInit;

    // Default rights. This should be doable from ext configuration
    global.groups.("auth.guest").rights.("packages.*").("read") = true
}

main {
    [debug()() {
        // TODO This should obviously not be left in.
        value -> global.sessions; DebugPrintValue;
        value -> global.groups; DebugPrintValue
    }]

    [register(request)(Auth.out.token) {
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

        // TODO Create a new group with default rights!
        Auth.in.username = request.username;
        Auth.in.password = request.password;
        Auth
    }]

    [authenticate(request)(Auth.out.token) {
        username = request.username;
        password = request.password;
        Auth
    }]

    [invalidate(token)(response) {
        AuthTokenDeleteByToken.in.token = token;
        AuthTokenDeleteByToken
    }]

    [validate(request)(response) {
        session -> global.sessions.(request.token);
        AuthTokenFindByToken.in.token = request.token;
        AuthTokenFindByToken;

        if (#AuthTokenFindByToken.out.result == 1) {
            if (is_defined(request.maxAge)) {
                getCurrentTimeMillis@Time()(now);
                age = now - AuthTokenFindByToken.out.result.timestamp;
                response = age <= request.maxAge
            } else {
                response = true
            };
            if (response) {
                response.username = AuthTokenFindByToken.out.result.username
            }
        }
    }]

    [createGroup(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;
        global.groups.(groupName) << {
            .name = groupName
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
        GroupFind;
        change -> request.change[i];
        for (i = 0, i < #request.change, i++) {
            if (change.grant) {
                group.rights.(change.key).(change.right) = true
            } else {
                undef(group.rights.(change.key).(change.right))
            }
        }
    }]

    [addGroupMembers(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;
        GroupFind;
        for (i = 0, i < #request.users, i++) {
            group.members[#group.members] = request.users[i]
        }
    }]

    [removeGroupMembers(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;
        GroupFind;
        userToDelete -> request.users[i];
        for (i = 0, i < request.users, i++) {
            keepRun = true;
            for (j = 0, j < #group.members && keepRun, j++) {
                if (group.members[j] == userToDelete) {
                    undef(group.members[j]);
                    keepRun = false
                }
            }
        }
    }]

    [getGroup(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;
        GroupFind;
        response.name = groupName;
        response.members -> group.members;
        foreach (object : group.rights) {
            o.key = object;
            foreach (right : group.rights.(object)) {
                o.rights[#o.rights] = right
            };
            response.objects[#response.objects] << o
        }
    }]

    [listGroupsByUser(request)(response) {
        username = request.username;
        FindAllGroupsForUsername;
        response.groups -> groups
    }]

    [hasAllOfRights(request)(response) {
        response = true;
        token = request.token;
        FindAllGroupsForToken;
        group -> global.groups.(groups[j]);
        for (i = 0, i < #groups && response, i++) {
            found = false;
            for (j = 0, j < #groups && !found, j++) {
                if (!is_defined(group.rights
                        .(request.check[i].key).(request.check[i].right))) {
                    found = true
                }
            };
            if (!found) {
                response = false
            }
        }
    }]

    [hasAnyOfRights(request)(response) {
        response = false;
        token = request.token;
        FindAllGroupsForToken;
        group -> global.groups.(groups[j]);
        currentCheck -> request.check[i];
        for (i = 0, i < #request.check && !response, i++) {
            for (j = 0, j < #groups && !response, j++) {
                if (is_defined(group.rights
                        .(currentCheck.key).(currentCheck.right))) {
                    response = true
                }
            }
        }
    }]

    [revokeRights(request)(response) {
        groupName = request.groupName;
        GroupRequireNonAuth;
        GroupFind;
        undef(group.rights.(request.key))
    }]
}
