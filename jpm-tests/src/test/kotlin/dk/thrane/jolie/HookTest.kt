package dk.thrane.jolie

import org.junit.Assert.*
import org.hamcrest.CoreMatchers.*
import org.junit.Test
import java.io.File

class HookTest {
    val SOURCE_DIR = File("jolie-tests/life-time-hooks")
    val VALID_HOOK_DIR = File(SOURCE_DIR, "hook-test")
    val VALID_PRE_OUT = File(VALID_HOOK_DIR, "pre_out.txt")
    val VALID_POST_OUT = File(VALID_HOOK_DIR, "post_out.txt")

    val INVALID_HOOK_DIR = File(SOURCE_DIR, "invalid-hook-test")
    val INVALID_PRE_OUT = File(INVALID_HOOK_DIR, "pre_out.txt")
    val INVALID_POST_OUT = File(INVALID_HOOK_DIR, "post_out.txt")

    @Test
    fun testThatSourcesExist() {
        assertTrue(SOURCE_DIR.exists())
        assertTrue(VALID_HOOK_DIR.exists())
        assertTrue(INVALID_HOOK_DIR.exists())
    }

    @Test
    fun testThatAllValidHooksRun() {
        JPM.withRegistry {
            registerAndAuthenticate()

            VALID_PRE_OUT.delete()
            VALID_POST_OUT.delete()

            JPM(VALID_HOOK_DIR, listOf("start")).runAndAssert()
            assertEquals("pre-start", VALID_PRE_OUT.readLines().first())
            assertEquals("post-start", VALID_POST_OUT.readLines().first())

            JPM(VALID_HOOK_DIR, listOf("install")).runAndAssert()
            assertEquals("pre-install", VALID_PRE_OUT.readLines().first())
            assertEquals("post-install", VALID_POST_OUT.readLines().first())

            JPM(VALID_HOOK_DIR, listOf("publish")).runAndAssert()
            assertEquals("pre-publish", VALID_PRE_OUT.readLines().first())
            assertEquals("post-publish", VALID_POST_OUT.readLines().first())
        }
    }

    @Test
    fun testThatAllInvalidHooksStopCode() {
        JPM.withRegistry {
            registerAndAuthenticate()

            INVALID_PRE_OUT.delete()
            INVALID_POST_OUT.delete()

            val startResult = JPM(INVALID_HOOK_DIR, listOf("start")).run()
            assertEquals(400, startResult.exitCode)
            assertThat(startResult.stdOut, hasItem(containsString("non-zero status code (1)")))
            assertEquals("pre-start", INVALID_PRE_OUT.readLines().first())
            assertFalse(INVALID_POST_OUT.exists())

            val installResult = JPM(INVALID_HOOK_DIR, listOf("install")).run()
            assertEquals(400, installResult.exitCode)
            assertThat(installResult.stdOut, hasItem(containsString("non-zero status code (1)")))
            assertEquals("pre-install", INVALID_PRE_OUT.readLines().first())
            assertFalse(INVALID_POST_OUT.exists())

            val publishResult = JPM(INVALID_HOOK_DIR, listOf("publish")).run()
            assertEquals(400, publishResult.exitCode)
            assertThat(publishResult.stdOut, hasItem(containsString("non-zero status code (1)")))
            assertEquals("pre-publish", INVALID_PRE_OUT.readLines().first())
            assertFalse(INVALID_POST_OUT.exists())
        }
    }
}

