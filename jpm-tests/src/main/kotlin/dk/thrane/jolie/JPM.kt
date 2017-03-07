package dk.thrane.jolie

import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.InputStreamReader
import java.util.*
import org.junit.Assert.*

class JPM(
        val folder: File,
        val command: List<String>,
        val input: File? = null
) {
    companion object {
        val PATTERN = "Error.*! (\\d+).*".toRegex()

        val PACKAGES_FOLDER_NAME = "jpm_packages"

        val TEST_DATABASE_LOC = File("/tmp/registry-test.db")
        val TEST_DATABASE_LOC2 = File("/tmp/auth-test.db")
        val TEST_DATA_DIR = File("/tmp/registry-data")
        val DEPLOY_REGISTRY = JPM(
                File(System.getenv("JPM_CLI_HOME"), "../registry"),
                listOf("start", "--deploy", "reg-test", "test.col")
        )
        val KILL_REGISTRY = JPM(
                File(System.getenv("JPM_CLI_HOME"), "../registry-admin"),
                listOf("start", "--deploy", "testenv-kill", "deployment.col")
        )

        fun withRegistry(printIO: Boolean = true, stdOutCallBack: (String) -> Unit = {}, block: () -> Unit) {
            val registryProcess = JPM.DEPLOY_REGISTRY.startProcess()
            var ready = false

            if (TEST_DATABASE_LOC.exists()) {
                assert(TEST_DATABASE_LOC.delete())
            }

            if (TEST_DATABASE_LOC2.exists()) {
                assert(TEST_DATABASE_LOC2.delete())
            }

            if (TEST_DATA_DIR.exists()) {
                assert(TEST_DATA_DIR.deleteRecursively())
            }
            assert(TEST_DATA_DIR.mkdirs())

            Thread({
                BufferedReader(InputStreamReader(registryProcess.inputStream)).forEachLine {
                    if (printIO) println(it)
                    if (it.toLowerCase().contains("ready")) ready = true
                    stdOutCallBack(it)
                }

                BufferedReader(InputStreamReader(registryProcess.errorStream)).forEachLine {
                    if (printIO) System.err.println(it)
                }
            }).start()

            val timeout = System.currentTimeMillis() + 30000
            while (!ready && System.currentTimeMillis() < timeout) {
                Thread.sleep(50)
            }

            assert(ready)
            try {
                block()
            } finally {
                JPM.KILL_REGISTRY.run()
                registryProcess.waitFor()
            }
        }
    }

    fun startProcess(): Process {
        val builder = ProcessBuilder()
        builder.directory(folder)
        builder.command(listOf("jpmdev") + command)
        if (input != null) {
            builder.redirectInput(input)
        }
        return builder.start()
    }

    fun run(): JPMResult {
        val process = startProcess()
        val stdOut = ArrayList<String>()
        val stdErr = ArrayList<String>()
        val readerOut = readFully(process.inputStream, stdOut)
        val readerErr = readFully(process.errorStream, stdErr)
        readerOut.start()
        readerErr.start()
        process.waitFor()
        readerOut.join()
        readerErr.join()

        var exitCode: Int = 0
        var message: String? = null

        val errorLine = stdOut.indexOfFirst { it.startsWith("Error") }
        if (errorLine != -1) {
            exitCode = PATTERN.matchEntire(stdOut[errorLine])!!.groupValues[1].toInt()
            message = stdOut.takeLast(stdOut.size - errorLine).joinToString("\n") { it }
        }

        val exceptionLine = stdErr.indexOfFirst { it.startsWith("SEVERE:") && it.contains("jpm/main.ol") }

        if (exceptionLine != -1) {
            return JPMResult(stdOut, stdErr, -1, "JPM threw an exception")
        }

        return JPMResult(stdOut, stdErr, exitCode, message)
    }

    fun runAndAssert(): JPMResult = run().assertSuccess()

    private fun readFully(from: InputStream, to: MutableList<String>) = Thread({
        val reader = BufferedReader(InputStreamReader(from))
        to.addAll(reader.readLines())
    })
}

class JPMResult(
        val stdOut: List<String>,
        val stdErr: List<String>,
        val exitCode: Int,
        val exitMessage: String?
) {
    fun assertSuccess(): JPMResult {
        if (exitCode != 0 || exitMessage != null) {
            stdOut.forEach(::println)
            stdErr.forEach { System.err.println(it) }
        }
        assertEquals(0, exitCode)
        assertNull(exitMessage)
        return this
    }
}
