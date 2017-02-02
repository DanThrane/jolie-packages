package dk.thrane.jolie

import org.junit.Test
import java.io.File
import org.junit.Assert.*
import org.hamcrest.CoreMatchers.*

class RegistryDeployTest {
    @Test
    fun testRegistryDeployment() {
        JPM.withRegistry {
            val pingResult = JPM(File("."), listOf("ping")).run()
            assertEquals(0, pingResult.exitCode)
            assertThat(pingResult.stdOut, hasItem("OK"))
        }
    }

    @Test
    fun testPingNoRegistry() {
        val pingResult = JPM(File("."), listOf("ping")).run()
        assertEquals(500, pingResult.exitCode)
        assertThat(pingResult.exitMessage, containsString("Unable to contact registry"))
    }
}

