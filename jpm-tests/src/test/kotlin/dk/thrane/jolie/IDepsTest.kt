package dk.thrane.jolie

import org.junit.Assert.*
import org.hamcrest.CoreMatchers.*
import org.junit.Test
import java.io.File

class IDepsTest {
    val SOURCE_DIR = File("jolie-tests/publish-with-ideps")

    val INSTALL_IDEP_TARGET = "install-idep"
    val INSTALL_IDEP_TARGET_DIR = File(SOURCE_DIR, INSTALL_IDEP_TARGET)

    val INSTALL_DEP_TARGET = "install-dep"
    val INSTALL_DEP_TARGET_DIR = File(SOURCE_DIR, INSTALL_DEP_TARGET)

    val DEP_A = "depA"
    val DEP_A_DIR = File(SOURCE_DIR, DEP_A)

    val DEP_B = "depB"
    val DEP_B_DIR = File(SOURCE_DIR, DEP_B)

    val DEP_C = "depC"
    val DEP_C_DIR = File(SOURCE_DIR, DEP_C)

    @Test
    fun testThatSourceCodeExists() {
        assertTrue(SOURCE_DIR.exists())
        assertTrue(INSTALL_IDEP_TARGET_DIR.exists())
        assertTrue(INSTALL_DEP_TARGET_DIR.exists())
        assertTrue(DEP_A_DIR.exists())
        assertTrue(DEP_B_DIR.exists())
        assertTrue(DEP_C_DIR.exists())
    }

    @Test
    fun testInterfaceDependencies() {
        JPM.withRegistry {
            val installedPackages = File(INSTALL_IDEP_TARGET_DIR, JPM.PACKAGES_FOLDER_NAME)
            deleteDirectoryNowAndOnExit(installedPackages)

            File(INSTALL_DEP_TARGET_DIR, "jpm_lock.json").delete()

            registerAndAuthenticate()

            // Publish our package
            JPM(DEP_C_DIR, listOf("publish")).runAndAssert()
            JPM(DEP_B_DIR, listOf("publish")).runAndAssert()
            JPM(DEP_A_DIR, listOf("publish")).runAndAssert()

            // Install the package
            JPM(INSTALL_IDEP_TARGET_DIR, listOf("install")).runAndAssert()

            // Check if package was installed
            assertThat(INSTALL_IDEP_TARGET_DIR.list().toList(), hasItem(JPM.PACKAGES_FOLDER_NAME))
            assertEquals(2, installedPackages.list().size)
            assertThat(installedPackages.list().toList(), hasItem(DEP_A))
            assertThat(installedPackages.list().toList(), hasItem(DEP_B))
        }
    }

    @Test
    fun testDependencies() {
        JPM.withRegistry {
            val installedPackages = File(INSTALL_DEP_TARGET_DIR, JPM.PACKAGES_FOLDER_NAME)
            deleteDirectoryNowAndOnExit(installedPackages)

            File(INSTALL_DEP_TARGET_DIR, "jpm_lock.json").delete()

            registerAndAuthenticate()

            // Publish our package
            JPM(DEP_C_DIR, listOf("publish")).runAndAssert()
            JPM(DEP_B_DIR, listOf("publish")).runAndAssert()
            JPM(DEP_A_DIR, listOf("publish")).runAndAssert()

            // Install the package
            JPM(INSTALL_DEP_TARGET_DIR, listOf("install")).runAndAssert()

            // Check if package was installed
            assertThat(INSTALL_DEP_TARGET_DIR.list().toList(), hasItem(JPM.PACKAGES_FOLDER_NAME))
            assertEquals(3, installedPackages.list().size)
            assertThat(installedPackages.list().toList(), hasItem(DEP_A))
            assertThat(installedPackages.list().toList(), hasItem(DEP_B))
            assertThat(installedPackages.list().toList(), hasItem(DEP_C))
        }
    }

    private fun deleteDirectoryNowAndOnExit(directory: File) {
        if (directory.exists()) directory.deleteRecursively()
        directory.deleteOnExit()
        assert(!directory.exists())
    }
}

