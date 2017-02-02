package dk.thrane.jolie

import org.junit.Assert.*
import org.hamcrest.CoreMatchers.*
import org.junit.Test
import java.io.File

class JPMAuthTest {
    @Test
    fun testRegistration() {
        val username = "user"
        val password = "1234"

        val result = JPM(File("."), listOf("register", username, password)).run()
        assertEquals(0, result.exitCode)
        assertNull(result.exitMessage)

        val whoamiResult = JPM(File("."), listOf("whoami")).run()
        assertEquals(0, whoamiResult.exitCode)
        assertNull(whoamiResult.exitMessage)
        assertThat(whoamiResult.stdOut, hasItem(username))

        val logoutResult = JPM(File("."), listOf("logout")).run()
        assertEquals(0, logoutResult.exitCode)

        val resultSecond = JPM(File("."), listOf("register", username, password)).run()
        assertEquals(400, resultSecond.exitCode)
    }
}
