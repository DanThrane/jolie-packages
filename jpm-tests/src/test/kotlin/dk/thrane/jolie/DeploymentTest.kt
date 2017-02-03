package dk.thrane.jolie

import org.junit.Test
import java.io.File
import org.junit.Assert.*
import org.hamcrest.CoreMatchers.*

class DeploymentTest {
    val folder = File("jolie-tests/configuration-and-cli-arguments")

    @Test
    fun testDeploymentWithDefaults() {
        assertTrue(folder.exists())
        val result = JPM(folder, listOf("start", "--deploy",
                "with-defaults", "deployment.col")).run()
        assertEquals(0, result.exitCode)
        assertNull(result.exitMessage)
        assertThat(result.stdOut, hasItem("TOKEN=1234"))
        assertThat(result.stdOut, hasItem("SOME_OTHER_TOKEN=Testing default configuration"))
        assertThat(result.stdOut, hasItem("#args=0"))
    }

    @Test
    fun testDeploymentWithDefaultsOverwritten() {
        assertTrue(folder.exists())
        val result = JPM(folder, listOf("start", "--deploy",
                "without-defaults", "deployment.col")).run()
        assertEquals(0, result.exitCode)
        assertNull(result.exitMessage)
        assertThat(result.stdOut, hasItem("TOKEN=1234"))
        assertThat(result.stdOut, hasItem("SOME_OTHER_TOKEN=Do we override?"))
        assertThat(result.stdOut, hasItem("#args=0"))
    }

    @Test
    fun testDeploymentWithDefaultsOverwrittenAndArguments() {
        assertTrue(folder.exists())
        val result = JPM(folder, listOf("start", "--deploy",
                "without-defaults", "deployment.col", "arg1", "arg2", "arg3")).run()
        assertEquals(0, result.exitCode)
        assertNull(result.exitMessage)
        assertThat(result.stdOut, hasItem("TOKEN=1234"))
        assertThat(result.stdOut, hasItem("SOME_OTHER_TOKEN=Do we override?"))
        assertThat(result.stdOut, hasItem("#args=3"))
        assertThat(result.stdOut, hasItem("args[0]=arg1"))
        assertThat(result.stdOut, hasItem("args[1]=arg2"))
        assertThat(result.stdOut, hasItem("args[2]=arg3"))
    }

    @Test
    fun testDeploymentWithDefaultsAndArguments() {
        assertTrue(folder.exists())
        val result = JPM(folder, listOf("start", "--deploy",
                "with-defaults", "deployment.col", "arg1", "arg2", "arg3")).run()
        assertEquals(0, result.exitCode)
        assertNull(result.exitMessage)
        assertThat(result.stdOut, hasItem("TOKEN=1234"))
        assertThat(result.stdOut, hasItem("SOME_OTHER_TOKEN=Testing default configuration"))
        assertThat(result.stdOut, hasItem("#args=3"))
        assertThat(result.stdOut, hasItem("args[0]=arg1"))
        assertThat(result.stdOut, hasItem("args[1]=arg2"))
        assertThat(result.stdOut, hasItem("args[2]=arg3"))
    }
}
