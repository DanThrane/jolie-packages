package dk.thrane.jolie

import com.google.gson.Gson
import com.google.gson.JsonObject
import org.junit.Assert.*
import org.hamcrest.CoreMatchers.*
import org.junit.Test
import java.io.File
import java.io.FileReader
import com.github.salomonbrys.kotson.*

class PublishAndInstallTest {
    val SOURCE_DIR = File("jolie-tests/publish")

    val INSTALL_TARGET = "install-target"
    val INSTALL_TARGET_DIR = File(SOURCE_DIR, INSTALL_TARGET)

    val PUBLISH_TARGET = "publish-target"
    val PUBLISH_TARGET_DIR = File(SOURCE_DIR, PUBLISH_TARGET)

    val INSTALL_TARGET_NEWEST = "install-target-newest"
    val INSTALL_TARGET_NEWEST_DIR = File(SOURCE_DIR, INSTALL_TARGET_NEWEST)

    val PUBLISH_TARGET_VER2 = "publish-target2"
    val PUBLISH_TARGET_VER2_DIR = File(SOURCE_DIR, PUBLISH_TARGET_VER2)

    val gson = Gson()

    @Test
    fun testThatSourceCodeExists() {
        assertTrue(SOURCE_DIR.exists())
        assertTrue(INSTALL_TARGET_DIR.exists())
        assertTrue(PUBLISH_TARGET_DIR.exists())
        assertTrue(INSTALL_TARGET_NEWEST_DIR.exists())
        assertTrue(PUBLISH_TARGET_VER2_DIR.exists())
    }

    @Test
    fun testPublishAndInstall() {
        JPM.withRegistry {
            val installedPackages = File(INSTALL_TARGET_DIR, JPM.PACKAGES_FOLDER_NAME)
            deleteDirectoryNowAndOnExit(installedPackages)

            registerAndAuthenticate()

            // Publish our package
            JPM(PUBLISH_TARGET_DIR, listOf("publish")).runAndAssert()

            // Install the package
            JPM(INSTALL_TARGET_DIR, listOf("install")).runAndAssert()

            // Check if package was installed
            assertThat(INSTALL_TARGET_DIR.list().toList(), hasItem(JPM.PACKAGES_FOLDER_NAME))
            assertThat(installedPackages.list().toList(), hasItem(PUBLISH_TARGET))

            // Ensure that there were no errors by running the install-target
            val startResult = JPM(INSTALL_TARGET_DIR, listOf("start")).runAndAssert()
            assertThat(startResult.stdOut, hasItem("publish-target: OK"))
            assertThat(startResult.stdOut, hasItem("Hello, Dan!"))
        }
    }

    @Test
    fun testNewestVersionResolution() {
        JPM.withRegistry {
            val installedPackages = File(INSTALL_TARGET_NEWEST_DIR, JPM.PACKAGES_FOLDER_NAME)
            deleteDirectoryNowAndOnExit(installedPackages)
            val manifestFile = File(File(installedPackages, PUBLISH_TARGET), "package.json")

            registerAndAuthenticate()

            // Publish version 0.1.0
            JPM(PUBLISH_TARGET_DIR, listOf("publish")).runAndAssert()

            // Install newest version (0.1.0)
            JPM(INSTALL_TARGET_NEWEST_DIR, listOf("install")).runAndAssert()

            // Check installed version
            assertTrue(manifestFile.exists())
            val manifest = gson.fromJson<JsonObject>(FileReader(manifestFile))
            assertEquals("0.1.0", manifest["version"].string)

            // Publish version 2.0.0
            JPM(PUBLISH_TARGET_VER2_DIR, listOf("publish")).runAndAssert()

            // Install newest version (2.0.0)
            JPM(INSTALL_TARGET_NEWEST_DIR, listOf("install")).runAndAssert()

            // Check installed version
            assertTrue(manifestFile.exists())
            val newManifest = gson.fromJson<JsonObject>(FileReader(manifestFile))
            assertEquals("2.0.0", newManifest["version"].string)
        }
    }

    private fun deleteDirectoryNowAndOnExit(directory: File) {
        if (directory.exists()) directory.deleteRecursively()
        directory.deleteOnExit()
        assert(!directory.exists())
    }
}
