package dk.thrane.jolie.manipulator

import jolie.CommandLineParser
import jolie.lang.parse.ast.OneWayOperationDeclaration
import jolie.lang.parse.ast.RequestResponseOperationDeclaration
import jolie.lang.parse.ast.types.*
import jolie.lang.parse.util.ParsingUtils
import java.io.BufferedReader
import java.io.File

data class Change(val isAddition: Boolean, val change: String)
data class InterfaceChange(val name: String, val changes: List<Change>)

fun require(actual: String, expected: String) {
    if (actual != expected) {
        throw IllegalStateException("Expected $expected got $actual")
    }
}

fun parse(reader: BufferedReader): InterfaceChange? {
    var nextLine: String? = reader.readLine()
    while (nextLine != null && nextLine.trim().isBlank()) {
        nextLine = reader.readLine()
    }

    if (nextLine == null) {
        return null
    }

    val firstSplit = reader.readLine().split(" ")
    require(firstSplit[0], "interface")
    require(firstSplit[2], "{")
    val name = firstSplit[1]

    val changes = ArrayList<Change>()

    nextLine = reader.readLine()
    while (nextLine != null) {
        nextLine = nextLine.trim()
        if (nextLine == "}") return InterfaceChange(name, changes)
        if (nextLine.isBlank()) continue

        val sign = nextLine[0]
        if (sign != '+' && sign != '-') throw IllegalStateException("Expected + or -")

        val isAddition = sign == '+'
        val change = nextLine.substring(1)
        changes.add(Change(isAddition, change))

        nextLine = reader.readLine()
    }

    throw IllegalStateException("Unexpected EOF")
}

fun typeName(decl: TypeDefinition): String =
        when (decl) {
            is TypeDefinitionLink -> decl.linkedTypeName()
            is TypeDefinitionUndefined -> "undefined"
            is TypeChoiceDefinition -> typeName(decl.left()) + " | " + typeName(decl.right())
            else -> throw IllegalStateException()
        }

fun main(args: Array<String>) {
    val cmdParser = CommandLineParser(args, ClassLoader.getSystemClassLoader())

    val program = ParsingUtils.parseProgram(
            cmdParser.programStream(),
            cmdParser.programFilepath().toURI(), cmdParser.charset(),
            cmdParser.includePaths(), cmdParser.jolieClassLoader(), cmdParser.definedConstants(), null,
            cmdParser.knownPackages(), cmdParser.thisPackage(),
            cmdParser.configurationFile(), cmdParser.configurationProfile())
    val inspector = ParsingUtils.createInspector(program)

    val reader = File(cmdParser.arguments()[0]).bufferedReader()
    val allChanges = ArrayList<InterfaceChange>()
    while (true) {
        val result = parse(reader) ?: break
        allChanges.add(result)
    }

    val targetInterfaceName = cmdParser.arguments()[1]
    val outputFile = cmdParser.arguments()[2]
    //val out = PrintWriter(File(outputFile).outputStream())
    val out = System.out

    val actualInterface = inspector.interfaces.find { it.name() == targetInterfaceName }!!
    val indent = "    "

    // Write proxied interface
    out.println("interface P${actualInterface.name()} {")
    val ow = actualInterface.operationsMap().values.filterIsInstance(OneWayOperationDeclaration::class.java)
    val rr = actualInterface.operationsMap().values.filterIsInstance(RequestResponseOperationDeclaration::class.java)

    val allTypes = (ow.map { it.requestType() } + rr.map { it.requestType() } + rr.map { it.responseType() }).toSet()
    allTypes.forEach {
        when (it) {
            is TypeInlineDefinition -> {
                out.print(indent)
                out.print("P${it.id()}: ${it.nativeType().id()}")
                if (it.hasSubTypes()) {
                    out.println(" {")
                    it.subTypes().forEach { sub ->
                        if (sub.value is TypeDefinitionLink && allTypes.find {
                            it.id() == (sub.value as TypeDefinitionLink).linkedTypeName()
                        } != null) {
                            out.println(".${sub.key}: P${typeName(sub.value)}")
                        } else {
                            out.println(".${sub.key}: ${typeName(sub.value)}")
                        }
                    }
                } else {
                    out.println()
                }
            }
        }
    }

    if (ow.isNotEmpty()) {
        out.println("OneWay:")
        out.println(
                ow.map {
                    "${indent}${it.id()}(P${typeName(it.requestType())}"
                }
        )
    }

    if (rr.isNotEmpty()) {
        out.println("RequestResponse:")
        out.println(
                rr.map {
                    "${indent}${it.id()}(P(${typeName(it.requestType())})(P${typeName(it.responseType())})"
                }.joinToString()
        )
    }
}
