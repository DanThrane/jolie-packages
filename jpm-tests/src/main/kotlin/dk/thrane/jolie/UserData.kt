package dk.thrane.jolie

import java.io.File
import java.util.*

private val random = Random()

data class User(val name: String, val password: String)

fun registerAndAuthenticate(name: String = "user", withRandomSuffix: Boolean = true): User {
    val username = name + (if (withRandomSuffix) random.nextInt(1000) else "")
    val password = "123456"
    val result = JPM(File("."), listOf("register", username, password)).run()
    assert(result.exitCode == 0)
    return User(username, password)
}

fun authenticate(name: String = "user") {
    JPM(File("."), listOf("login", name, "123456")).runAndAssert()
}

fun reauthenticate(name: String = "user") {
    JPM(File("."), listOf("logout")).runAndAssert()
    authenticate(name)
}

