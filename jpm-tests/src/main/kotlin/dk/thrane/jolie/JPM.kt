package dk.thrane.jolie

import java.io.BufferedReader
import java.io.File
import java.io.InputStream
import java.io.InputStreamReader
import java.util.*

class JPM(
        val folder: File,
        val command: List<String>,
        val input: File? = null
) {
    companion object {
        val PATTERN = "Error.*! (\\d+).*".toRegex()

        val DEPLOY_REGISTRY = JPM(File(System.getenv("JPM_CLI_HOME"), "../registry"), listOf("start"))
        val KILL_REGISTRY = JPM(File(System.getenv("JPM_CLI_HOME"), "../registry-admin"),
                listOf("start", "--deploy", "testenv-kill", "deployment.col"))

        fun withRegistry(printStdOut: Boolean = false, stdOutCallBack: (String) -> Unit = {}, block: () -> Unit) {
            val registryProcess = JPM.DEPLOY_REGISTRY.startProcess()
            var ready = false
            Thread({
                BufferedReader(InputStreamReader(registryProcess.inputStream)).forEachLine {
                    if (printStdOut) println(it)
                    if (it.toLowerCase().contains("ready")) ready = true
                    stdOutCallBack(it)
                }
            }).start()
            val timeout = System.currentTimeMillis() + 10000
            while (!ready && System.currentTimeMillis() < timeout) {
                Thread.sleep(50)
            }
            assert(ready)
            block()
            JPM.KILL_REGISTRY.run()
            registryProcess.waitFor()
        }
    }

    fun startProcess(): Process {
        val builder = ProcessBuilder()
        builder.directory(folder)
        builder.command(listOf("jpm") + command)
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
            val trace = stdErr.takeLast(stdErr.size - exceptionLine).joinToString("\n") { it }
            throw IllegalStateException("JPM threw an exception: \n$trace")
        }

        return JPMResult(stdOut, stdErr, exitCode, message)
    }

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
)
