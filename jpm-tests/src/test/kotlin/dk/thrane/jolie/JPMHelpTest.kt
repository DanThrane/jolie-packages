package dk.thrane.jolie

import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.hamcrest.CoreMatchers.*

class JPMHelpTest {
    @Test
    fun testHelpText() {
        val result = JPM(File("."), listOf("help")).run()
        assertEquals(0, result.exitCode)
        assertEquals(null, result.exitMessage)
        assert(result.stdOut.size >= 2)
        assertThat(result.stdOut[0], containsString("JPM"))
        assertThat(result.stdOut[1], containsString("Version"))
    }

    @Test
    fun testNoCommandIsHelpCommand() {
        val result = JPM(File("."), emptyList()).run()
        val result2 = JPM(File("."), listOf("help")).run()

        assertEquals(result.stdErr, result2.stdErr)
        assertEquals(result.stdOut, result2.stdOut)
        assertEquals(result.exitMessage, result2.exitMessage)
        assertEquals(result.exitCode, result2.exitCode)
    }
}
