package dk.thrane.jolie

import org.junit.Assert.*
import org.hamcrest.CoreMatchers.*
import org.junit.Test
import java.io.File
import java.nio.file.Files
import com.github.salomonbrys.kotson.*
import com.google.gson.Gson
import com.google.gson.JsonObject
import java.io.FileReader

class InitTest {
    val gson = Gson()

    @Test
    fun testInitialization() {
        val directory = Files.createTempDirectory("jpm-package-test").toFile()
        val inputFile = File.createTempFile("jpm-package-input", null)
        val packageName = "package-name"
        val description = "Test description"
        val author = "An Author <foo@mail.com>"
        inputFile.writeText("$packageName\n$description\n$author\ny\n")

        val result = JPM(directory, listOf("init"), inputFile).run()
        assertEquals(0, result.exitCode)
        assertNull(result.exitMessage)
        assertEquals(1, directory.listFiles().size)
        assertThat(directory.list().toList(), hasItem(packageName))
        val packageFolder = File(directory, packageName)
        assertTrue(packageFolder.exists())
        val packageManifest = File(packageFolder, "package.json")
        assertTrue(packageManifest.exists())
        val jsonManifest = gson.fromJson<JsonObject>(FileReader(packageManifest))
        assertEquals(packageName, jsonManifest["name"].string)
        assertEquals(description, jsonManifest["description"].string)
        assertEquals("0.1.0", jsonManifest["version"].string)
        assertEquals(author, jsonManifest["authors"].string)
        assertTrue(jsonManifest["private"].bool)
    }

    @Test
    fun testInitializationWithInvalidAuthor() {
        val directory = Files.createTempDirectory("jpm-package-test").toFile()
        val inputFile = File.createTempFile("jpm-package-input", null)
        val packageName = "package-name"
        val description = "Test description"
        val author = "asd asd (asdasd.dk) <asdasd@asdasd>"
        inputFile.writeText("$packageName\n$description\n$author\ny\n")

        val result = JPM(directory, listOf("init"), inputFile).run()
        assertEquals(400, result.exitCode)
        assertNotNull(result.exitMessage)
        assertThat(result.stdOut, hasItem(containsString("Authors must use the following convention")))
    }
}
