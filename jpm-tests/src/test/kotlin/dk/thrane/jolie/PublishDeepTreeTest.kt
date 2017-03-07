package dk.thrane.jolie

import junit.framework.Assert.assertTrue
import java.io.File

import org.junit.Assert.*
import com.github.salomonbrys.kotson.*
import org.hamcrest.CoreMatchers.*
import org.junit.Test

class PublishDeepTreeTest {
    val PUBLISH_DEEP = File("jolie-tests/publish-with-deep-tree")

    val DEP_A = "depA"
    val DEP_A_DIR = File(PUBLISH_DEEP, DEP_A)

    val DEP_B = "depB"
    val DEP_B_DIR = File(PUBLISH_DEEP, DEP_B)

    val INSTALL_TARGET = "install-target"
    val INSTALL_TARGET_DIR = File(PUBLISH_DEEP, INSTALL_TARGET)

    val DEP_C = "depC"
    val DEP_C_DIR = File(PUBLISH_DEEP, DEP_C)

    @Test
    fun testThatSourcesExists() {
        assertTrue(PUBLISH_DEEP.exists())
        assertTrue(DEP_A_DIR.exists())
        assertTrue(DEP_B_DIR.exists())
        assertTrue(DEP_C_DIR.exists())
        assertTrue(INSTALL_TARGET_DIR.exists())
    }

    @Test
    fun testThatPublishAndInstallWorks() {
        JPM.withRegistry {
            registerAndAuthenticate()

            JPM(DEP_C_DIR, listOf("publish")).runAndAssert()

            val bPackages = File(DEP_B_DIR, "jpm_packages")
            bPackages.deleteRecursively()
            JPM(DEP_B_DIR, listOf("install")).runAndAssert()
            assertThat(bPackages.list().toList(), hasItem(DEP_C))
            JPM(DEP_B_DIR, listOf("publish")).runAndAssert()

            val aPackages = File(DEP_A_DIR, "jpm_packages")
            aPackages.deleteRecursively()
            JPM(DEP_A_DIR, listOf("install")).runAndAssert()
            assertThat(aPackages.list().toList(), hasItem(DEP_B))
            assertThat(aPackages.list().toList(), hasItem(DEP_C))
            JPM(DEP_A_DIR, listOf("publish")).runAndAssert()

            val installedPackages = File(INSTALL_TARGET_DIR, "jpm_packages")
            installedPackages.deleteRecursively()
            JPM(INSTALL_TARGET_DIR, listOf("install")).runAndAssert()
            assertThat(installedPackages.list().toList(), hasItem(DEP_A))
            assertThat(installedPackages.list().toList(), hasItem(DEP_B))
            assertThat(installedPackages.list().toList(), hasItem(DEP_C))
            JPM(INSTALL_TARGET_DIR, listOf("publish"))
        }
    }
}

