type PasswordCheckRequest: void {
    .password: string
    .hashed: string
}

interface IBCrypt {
    RequestResponse:
        hashPassword(string)(string),
        checkPassword(PasswordCheckRequest)(bool)
}

outputPort BCrypt {
    Interfaces: IBCrypt
}

embedded {
    Java:
        "dk.thrane.jolie.bcrypt.BCryptService" in BCrypt
}

