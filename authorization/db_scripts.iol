include "database.iol"
include "db_config.iol"

define DatabaseInit {
    DatabaseConnect;

    DatabaseInit.q = "
        CREATE TABLE IF NOT EXISTS 'user' (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE,
            password TEXT
        );
    ";
    update@Database(DatabaseInit.q)();

    DatabaseInit.q = "
        CREATE TABLE IF NOT EXISTS 'group' (
            id INTEGER PRIMARY KEY,
            groupName TEXT UNIQUE
        );
    ";
    update@Database(DatabaseInit.q)();

    DatabaseInit.q = "
        CREATE TABLE IF NOT EXISTS 'group_member' (
            id INTEGER PRIMARY KEY,
            userId INTERGER,
            groupId INTERGER,
            FOREIGN KEY (userId) REFERENCES 'user',
            FOREIGN KEY (groupId) REFERENCES 'group'
        );
    ";
    update@Database(DatabaseInit.q)();

    DatabaseInit.q = "
        CREATE TABLE IF NOT EXISTS 'group_rights' (
            id INTEGER PRIMARY KEY,
            groupId INTERGER,
            resource TEXT,
            value TEXT,
            FOREIGN KEY (groupId) REFERENCES 'group'
        );
    ";
    update@Database(DatabaseInit.q)();

    DatabaseInit.q = "
        CREATE TABLE IF NOT EXISTS 'auth_token' (
            id INTEGER PRIMARY KEY,
            token TEXT UNIQUE,
            timestamp DATE,
            userId INTERGER,
            FOREIGN KEY (userId) REFERENCES 'user'
        );
    ";
    update@Database(DatabaseInit.q)();
    nullProcess
}

define UserCreate {
    DatabaseConnect;
    UserCreate.q.statement[0] = "
        INSERT INTO `user` (`username`, `password`)
        VALUES (LOWER(:username), :password)
    ";
    UserCreate.q.statement[0].username = UserCreate.in.username;
    UserCreate.q.statement[0].password = UserCreate.in.password;
    UserCreate.q.statement[1] = "SELECT last_insert_rowid() AS id";
    executeTransaction@Database(UserCreate.q)(UserCreate.t);
    UserCreate.out.id = UserCreate.t.result[1].row[0].id
}
define UserDeleteById {
    DatabaseConnect;
    UserDeleteById.q = "DELETE FROM `user` WHERE `id` = :id";
    UserDeleteById.q.id = UserDeleteById.in.id;
    update@Database(UserDeleteById.q)(UserDeleteById.out.result)
}
define UserFindById {
    DatabaseConnect;
    UserFindById.q = "
        SELECT `id`, LOWER(`username`), `password`
        FROM `user`
        WHERE id = :id
    ";
    UserFindById.q.id = UserFindById.in.id;
    query@Database(UserFindById.q)(UserFindById.result);
    UserFindById._i = i;
    for (i = 0, i < #UserFindById.result.row, i++) {
        UserFindById.out.result[#UserFindById.out.result] << UserFindById.result.row[i]
    };
    i = UserFindById._i
}
define UserFindByUsername {
    DatabaseConnect;
    UserFindByUsername.q = "
        SELECT `id`, LOWER(`username`), `password`
        FROM `user`
        WHERE username = LOWER(:username)
    ";
    UserFindByUsername.q.username = UserFindByUsername.in.username;
    query@Database(UserFindByUsername.q)(UserFindByUsername.result);
    UserFindByUsername._i = i;
    for (i = 0, i < #UserFindByUsername.result.row, i++) {
        UserFindByUsername.out.result[#UserFindByUsername.out.result] << UserFindByUsername.result.row[i]
    };
    i = UserFindByUsername._i
}

define UserDeleteByUsername {
    DatabaseConnect;
    UserDeleteByUsername.q = "DELETE FROM `user` WHERE `username` = LOWER(:username)";
    UserDeleteByUsername.q.username = UserDeleteByUsername.in.username;
    update@Database(UserDeleteByUsername.q)(UserDeleteByUsername.out.result)
}

define GroupCreate {
    DatabaseConnect;
    GroupCreate.q.statement[0] = "
        INSERT INTO `group` (`groupName`)
        VALUES (:groupName)
    ";
    GroupCreate.q.statement[0].groupName = GroupCreate.in.groupName;
    GroupCreate.q.statement[1] = "SELECT last_insert_rowid() AS id";
    executeTransaction@Database(GroupCreate.q)(GroupCreate.t);
    GroupCreate.out.id = GroupCreate.t.result[1].row[0].id
}
define GroupDeleteById {
    DatabaseConnect;
    GroupDeleteById.q = "DELETE FROM `group` WHERE `id` = :id";
    GroupDeleteById.q.id = GroupDeleteById.in.id;
    update@Database(GroupDeleteById.q)(GroupDeleteById.out.result)
}
define GroupFindById {
    DatabaseConnect;
    GroupFindById.q = "
        SELECT `id`, `groupName`
        FROM `group`
        WHERE id = :id
    ";
    GroupFindById.q.id = GroupFindById.in.id;
    query@Database(GroupFindById.q)(GroupFindById.result);
    GroupFindById._i = i;
    for (i = 0, i < #GroupFindById.result.row, i++) {
        GroupFindById.out.result[#GroupFindById.out.result] << GroupFindById.result.row[i]
    };
    i = GroupFindById._i
}
define GroupFindByGroupName {
    DatabaseConnect;
    GroupFindByGroupName.q = "
        SELECT `id`, `groupName`
        FROM `group`
        WHERE groupName = :groupName
    ";
    GroupFindByGroupName.q.groupName = GroupFindByGroupName.in.groupName;
    query@Database(GroupFindByGroupName.q)(GroupFindByGroupName.result);
    GroupFindByGroupName._i = i;
    for (i = 0, i < #GroupFindByGroupName.result.row, i++) {
        GroupFindByGroupName.out.result[#GroupFindByGroupName.out.result] << GroupFindByGroupName.result.row[i]
    };
    i = GroupFindByGroupName._i
}

define GroupDeleteByGroupName {
    DatabaseConnect;
    GroupDeleteByGroupName.q = "DELETE FROM `group` WHERE `groupName` = :groupName";
    GroupDeleteByGroupName.q.groupName = GroupDeleteByGroupName.in.groupName;
    update@Database(GroupDeleteByGroupName.q)(GroupDeleteByGroupName.out.result)
}

define GroupMemberCreate {
    DatabaseConnect;
    GroupMemberCreate.q.statement[0] = "
        INSERT INTO `group_member` (`userId`, `groupId`)
        VALUES (:userId, :groupId)
    ";
    GroupMemberCreate.q.statement[0].userId = GroupMemberCreate.in.userId;
    GroupMemberCreate.q.statement[0].groupId = GroupMemberCreate.in.groupId;
    GroupMemberCreate.q.statement[1] = "SELECT last_insert_rowid() AS id";
    executeTransaction@Database(GroupMemberCreate.q)(GroupMemberCreate.t);
    GroupMemberCreate.out.id = GroupMemberCreate.t.result[1].row[0].id
}
define GroupMemberDeleteById {
    DatabaseConnect;
    GroupMemberDeleteById.q = "DELETE FROM `group_member` WHERE `id` = :id";
    GroupMemberDeleteById.q.id = GroupMemberDeleteById.in.id;
    update@Database(GroupMemberDeleteById.q)(GroupMemberDeleteById.out.result)
}
define GroupMemberFindById {
    DatabaseConnect;
    GroupMemberFindById.q = "
        SELECT `id`, `userId`, `groupId`
        FROM `group_member`
        WHERE id = :id
    ";
    GroupMemberFindById.q.id = GroupMemberFindById.in.id;
    query@Database(GroupMemberFindById.q)(GroupMemberFindById.result);
    GroupMemberFindById._i = i;
    for (i = 0, i < #GroupMemberFindById.result.row, i++) {
        GroupMemberFindById.out.result[#GroupMemberFindById.out.result] << GroupMemberFindById.result.row[i]
    };
    i = GroupMemberFindById._i
}
define GroupMemberFindByUserId {
    DatabaseConnect;
    GroupMemberFindByUserId.q = "
        SELECT `id`, `userId`, `groupId`
        FROM `group_member`
        WHERE userId = :userId
    ";
    GroupMemberFindByUserId.q.userId = GroupMemberFindByUserId.in.userId;
    query@Database(GroupMemberFindByUserId.q)(GroupMemberFindByUserId.result);
    GroupMemberFindByUserId._i = i;
    for (i = 0, i < #GroupMemberFindByUserId.result.row, i++) {
        GroupMemberFindByUserId.out.result[#GroupMemberFindByUserId.out.result] << GroupMemberFindByUserId.result.row[i]
    };
    i = GroupMemberFindByUserId._i
}

define GroupMemberDeleteByUserId {
    DatabaseConnect;
    GroupMemberDeleteByUserId.q = "DELETE FROM `group_member` WHERE `userId` = :userId";
    GroupMemberDeleteByUserId.q.userId = GroupMemberDeleteByUserId.in.userId;
    update@Database(GroupMemberDeleteByUserId.q)(GroupMemberDeleteByUserId.out.result)
}

define GroupMemberFindByGroupId {
    DatabaseConnect;
    GroupMemberFindByGroupId.q = "
        SELECT `id`, `userId`, `groupId`
        FROM `group_member`
        WHERE groupId = :groupId
    ";
    GroupMemberFindByGroupId.q.groupId = GroupMemberFindByGroupId.in.groupId;
    query@Database(GroupMemberFindByGroupId.q)(GroupMemberFindByGroupId.result);
    GroupMemberFindByGroupId._i = i;
    for (i = 0, i < #GroupMemberFindByGroupId.result.row, i++) {
        GroupMemberFindByGroupId.out.result[#GroupMemberFindByGroupId.out.result] << GroupMemberFindByGroupId.result.row[i]
    };
    i = GroupMemberFindByGroupId._i
}

define GroupMemberDeleteByGroupId {
    DatabaseConnect;
    GroupMemberDeleteByGroupId.q = "DELETE FROM `group_member` WHERE `groupId` = :groupId";
    GroupMemberDeleteByGroupId.q.groupId = GroupMemberDeleteByGroupId.in.groupId;
    update@Database(GroupMemberDeleteByGroupId.q)(GroupMemberDeleteByGroupId.out.result)
}

define GroupRightsCreate {
    DatabaseConnect;
    GroupRightsCreate.q.statement[0] = "
        INSERT INTO `group_rights` (`groupId`, `resource`, `value`)
        VALUES (:groupId, :resource, :value)
    ";
    GroupRightsCreate.q.statement[0].groupId = GroupRightsCreate.in.groupId;
    GroupRightsCreate.q.statement[0].resource = GroupRightsCreate.in.resource;
    GroupRightsCreate.q.statement[0].value = GroupRightsCreate.in.value;
    GroupRightsCreate.q.statement[1] = "SELECT last_insert_rowid() AS id";
    executeTransaction@Database(GroupRightsCreate.q)(GroupRightsCreate.t);
    GroupRightsCreate.out.id = GroupRightsCreate.t.result[1].row[0].id
}
define GroupRightsDeleteById {
    DatabaseConnect;
    GroupRightsDeleteById.q = "DELETE FROM `group_rights` WHERE `id` = :id";
    GroupRightsDeleteById.q.id = GroupRightsDeleteById.in.id;
    update@Database(GroupRightsDeleteById.q)(GroupRightsDeleteById.out.result)
}
define GroupRightsFindById {
    DatabaseConnect;
    GroupRightsFindById.q = "
        SELECT `id`, `groupId`, `resource`, `value`
        FROM `group_rights`
        WHERE id = :id
    ";
    GroupRightsFindById.q.id = GroupRightsFindById.in.id;
    query@Database(GroupRightsFindById.q)(GroupRightsFindById.result);
    GroupRightsFindById._i = i;
    for (i = 0, i < #GroupRightsFindById.result.row, i++) {
        GroupRightsFindById.out.result[#GroupRightsFindById.out.result] << GroupRightsFindById.result.row[i]
    };
    i = GroupRightsFindById._i
}
define GroupRightsFindByGroupId {
    DatabaseConnect;
    GroupRightsFindByGroupId.q = "
        SELECT `id`, `groupId`, `resource`, `value`
        FROM `group_rights`
        WHERE groupId = :groupId
    ";
    GroupRightsFindByGroupId.q.groupId = GroupRightsFindByGroupId.in.groupId;
    query@Database(GroupRightsFindByGroupId.q)(GroupRightsFindByGroupId.result);
    GroupRightsFindByGroupId._i = i;
    for (i = 0, i < #GroupRightsFindByGroupId.result.row, i++) {
        GroupRightsFindByGroupId.out.result[#GroupRightsFindByGroupId.out.result] << GroupRightsFindByGroupId.result.row[i]
    };
    i = GroupRightsFindByGroupId._i
}

define GroupRightsDeleteByGroupId {
    DatabaseConnect;
    GroupRightsDeleteByGroupId.q = "DELETE FROM `group_rights` WHERE `groupId` = :groupId";
    GroupRightsDeleteByGroupId.q.groupId = GroupRightsDeleteByGroupId.in.groupId;
    update@Database(GroupRightsDeleteByGroupId.q)(GroupRightsDeleteByGroupId.out.result)
}

define GroupRightsFindByResource {
    DatabaseConnect;
    GroupRightsFindByResource.q = "
        SELECT `id`, `groupId`, `resource`, `value`
        FROM `group_rights`
        WHERE resource = :resource
    ";
    GroupRightsFindByResource.q.resource = GroupRightsFindByResource.in.resource;
    query@Database(GroupRightsFindByResource.q)(GroupRightsFindByResource.result);
    GroupRightsFindByResource._i = i;
    for (i = 0, i < #GroupRightsFindByResource.result.row, i++) {
        GroupRightsFindByResource.out.result[#GroupRightsFindByResource.out.result] << GroupRightsFindByResource.result.row[i]
    };
    i = GroupRightsFindByResource._i
}

define GroupRightsDeleteByResource {
    DatabaseConnect;
    GroupRightsDeleteByResource.q = "DELETE FROM `group_rights` WHERE `resource` = :resource";
    GroupRightsDeleteByResource.q.resource = GroupRightsDeleteByResource.in.resource;
    update@Database(GroupRightsDeleteByResource.q)(GroupRightsDeleteByResource.out.result)
}

define GroupRightsFindByValue {
    DatabaseConnect;
    GroupRightsFindByValue.q = "
        SELECT `id`, `groupId`, `resource`, `value`
        FROM `group_rights`
        WHERE value = :value
    ";
    GroupRightsFindByValue.q.value = GroupRightsFindByValue.in.value;
    query@Database(GroupRightsFindByValue.q)(GroupRightsFindByValue.result);
    GroupRightsFindByValue._i = i;
    for (i = 0, i < #GroupRightsFindByValue.result.row, i++) {
        GroupRightsFindByValue.out.result[#GroupRightsFindByValue.out.result] << GroupRightsFindByValue.result.row[i]
    };
    i = GroupRightsFindByValue._i
}

define GroupRightsDeleteByValue {
    DatabaseConnect;
    GroupRightsDeleteByValue.q = "DELETE FROM `group_rights` WHERE `value` = :value";
    GroupRightsDeleteByValue.q.value = GroupRightsDeleteByValue.in.value;
    update@Database(GroupRightsDeleteByValue.q)(GroupRightsDeleteByValue.out.result)
}

define AuthTokenCreate {
    DatabaseConnect;
    AuthTokenCreate.q.statement[0] = "
        INSERT INTO `auth_token` (`token`, `timestamp`, `userId`)
        VALUES (:token, :timestamp, :userId)
    ";
    AuthTokenCreate.q.statement[0].token = AuthTokenCreate.in.token;
    AuthTokenCreate.q.statement[0].timestamp = AuthTokenCreate.in.timestamp;
    AuthTokenCreate.q.statement[0].userId = AuthTokenCreate.in.userId;
    AuthTokenCreate.q.statement[1] = "SELECT last_insert_rowid() AS id";
    executeTransaction@Database(AuthTokenCreate.q)(AuthTokenCreate.t);
    AuthTokenCreate.out.id = AuthTokenCreate.t.result[1].row[0].id
}
define AuthTokenDeleteById {
    DatabaseConnect;
    AuthTokenDeleteById.q = "DELETE FROM `auth_token` WHERE `id` = :id";
    AuthTokenDeleteById.q.id = AuthTokenDeleteById.in.id;
    update@Database(AuthTokenDeleteById.q)(AuthTokenDeleteById.out.result)
}
define AuthTokenFindById {
    DatabaseConnect;
    AuthTokenFindById.q = "
        SELECT `id`, `token`, `timestamp`, `userId`
        FROM `auth_token`
        WHERE id = :id
    ";
    AuthTokenFindById.q.id = AuthTokenFindById.in.id;
    query@Database(AuthTokenFindById.q)(AuthTokenFindById.result);
    AuthTokenFindById._i = i;
    for (i = 0, i < #AuthTokenFindById.result.row, i++) {
        AuthTokenFindById.out.result[#AuthTokenFindById.out.result] << AuthTokenFindById.result.row[i]
    };
    i = AuthTokenFindById._i
}
define AuthTokenFindByToken {
    DatabaseConnect;
    AuthTokenFindByToken.q = "
        SELECT `id`, `token`, `timestamp`, `userId`
        FROM `auth_token`
        WHERE token = :token
    ";
    AuthTokenFindByToken.q.token = AuthTokenFindByToken.in.token;
    query@Database(AuthTokenFindByToken.q)(AuthTokenFindByToken.result);
    AuthTokenFindByToken._i = i;
    for (i = 0, i < #AuthTokenFindByToken.result.row, i++) {
        AuthTokenFindByToken.out.result[#AuthTokenFindByToken.out.result] << AuthTokenFindByToken.result.row[i]
    };
    i = AuthTokenFindByToken._i
}

define AuthTokenDeleteByToken {
    DatabaseConnect;
    AuthTokenDeleteByToken.q = "DELETE FROM `auth_token` WHERE `token` = :token";
    AuthTokenDeleteByToken.q.token = AuthTokenDeleteByToken.in.token;
    update@Database(AuthTokenDeleteByToken.q)(AuthTokenDeleteByToken.out.result)
}

define AuthTokenFindByTimestamp {
    DatabaseConnect;
    AuthTokenFindByTimestamp.q = "
        SELECT `id`, `token`, `timestamp`, `userId`
        FROM `auth_token`
        WHERE timestamp = :timestamp
    ";
    AuthTokenFindByTimestamp.q.timestamp = AuthTokenFindByTimestamp.in.timestamp;
    query@Database(AuthTokenFindByTimestamp.q)(AuthTokenFindByTimestamp.result);
    AuthTokenFindByTimestamp._i = i;
    for (i = 0, i < #AuthTokenFindByTimestamp.result.row, i++) {
        AuthTokenFindByTimestamp.out.result[#AuthTokenFindByTimestamp.out.result] << AuthTokenFindByTimestamp.result.row[i]
    };
    i = AuthTokenFindByTimestamp._i
}

define AuthTokenDeleteByTimestamp {
    DatabaseConnect;
    AuthTokenDeleteByTimestamp.q = "DELETE FROM `auth_token` WHERE `timestamp` = :timestamp";
    AuthTokenDeleteByTimestamp.q.timestamp = AuthTokenDeleteByTimestamp.in.timestamp;
    update@Database(AuthTokenDeleteByTimestamp.q)(AuthTokenDeleteByTimestamp.out.result)
}

define AuthTokenFindByUserId {
    DatabaseConnect;
    AuthTokenFindByUserId.q = "
        SELECT `id`, `token`, `timestamp`, `userId`
        FROM `auth_token`
        WHERE userId = :userId
    ";
    AuthTokenFindByUserId.q.userId = AuthTokenFindByUserId.in.userId;
    query@Database(AuthTokenFindByUserId.q)(AuthTokenFindByUserId.result);
    AuthTokenFindByUserId._i = i;
    for (i = 0, i < #AuthTokenFindByUserId.result.row, i++) {
        AuthTokenFindByUserId.out.result[#AuthTokenFindByUserId.out.result] << AuthTokenFindByUserId.result.row[i]
    };
    i = AuthTokenFindByUserId._i
}

define AuthTokenDeleteByUserId {
    DatabaseConnect;
    AuthTokenDeleteByUserId.q = "DELETE FROM `auth_token` WHERE `userId` = :userId";
    AuthTokenDeleteByUserId.q.userId = AuthTokenDeleteByUserId.in.userId;
    update@Database(AuthTokenDeleteByUserId.q)(AuthTokenDeleteByUserId.out.result)
}

