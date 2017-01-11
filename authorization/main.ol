include "authorization.iol"
include "time.iol"
include "bcrypt" "bcrypt.iol"

execution { sequential }

inputPort Authorization {
    Location: "socket://localhost:44444"
    Protocol: sodep // Should be sodeps
    Interfaces: IAuthorization
}

/**
 * @input username: string
 * @output groups[0, *]: string
 */
define UserGroupsFind {
    nextGroup -> groups[#groups];
    foreach (group : global.groups) {
        keepRun = true;
        for (i = 0, i < #group.members && keepRun, i++) {
            if (group.members[i] == username) {
                nextGroup = group.name;
                keepRun = false
            }
        }
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
 * @input username: string
 * @input password: string
 * @output token: AccessToken
 * @throws AuthorizationFault if username and password doesn't match
 */
define Auth {
    invalidError << {
        .type = FAULT_BAD_REQUEST,
        .message = "Invalid username or password"
    };

    if (!is_defined(global.users.(username))) {
        throw(AuthorizationFault, invalidError)
    };

    checkPassword@BCrypt({
        .password = password,
        .hashed = global.users.(username)
    })(matches);
    
    if (!matches) {
        throw(AuthorizationFault, invalidError)
    };

    token = new;
    getCurrentTimeMillis@Time()(now);
    global.sessions.(token) << {
        .username = username,
        .timeCreated = now
    };

    undef(now);
    undef(invalidError)
}

init {
    install(AuthorizationFault => nullProcess)
}

main {
    [register(request)(token) {
        if (is_defined(global.users.(request.username))) {
            throw(AuthorizationFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Username is already taken!"
            })
        };

        hashPassword@BCrypt(request.password)(global.users.(request.username));
        username = request.username;
        password = request.password;
        Auth
    }]

    [authenticate(request)(token) {
        username = request.username;
        password = request.password;
        Auth
    }]

    [invalidate(token)(response) {
        undef(global.sessions.(token))
    }]

    [validate(request)(response) {
        session -> global.sessions.(request.token);
        if (is_defined(session)) {
            response.username = session.username;
            if (is_defined(request.maxAge)) {
                getCurrentTimeMillis@Time()(now);
                age = now - session.timeCreated;
                if (age > request.maxAge) {
                    response = false;
                    undef(response.username)
                } else {
                    response = true
                }
            } else {
                response = true
            }
        } else {
            response = false
        }
    }]

    [createGroup(request)(response) {
        global.groups.(request.groupName) << {
            .name = request.groupName
        }
    }]

    [deleteGroup(request)(response) {
        groupName = request.groupName;
        GroupFind;
        undef(group)
    }]

    [changeGroupRights(request)(response) {
        groupName = request.groupName;
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
        GroupFind;
        for (i = 0, i < request.users, i++) {
            group.members[#group.members] = request.users[i]
        }
    }]

    [removeGroupMembers(request)(response) {
        groupName = request.groupName;
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
        GroupFind;
        response.name = groupName;
        response.members -> group.members;
        foreach (object : group.rights) {
            o.key = object;
            foreach (right : group.rights.(object)) {
                o.rights[o.rights] = right
            };
            response.objects[#response.objects] << o
        }
    }]

    [listGroupsByUser(request)(response) {
        username = request.username;
        UserGroupsFind;
        response.groups -> groups
    }]

    [hasRights(request)(response) {
        session -> global.sessions.(request.token);
        response = false;
        if (is_defined(session)) {
            username = session.username;
            UserGroupsFind;
            group -> groups[i];
            for (i = 0, i < groups && !response, i++) {
                if (is_defined(group.rights.(key).(right))) {
                    response = true
                }
            }
        }
    }]    
}
