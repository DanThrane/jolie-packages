package dk.thrane.mock

import com.github.salomonbrys.kotson.*
import com.google.gson.JsonObject
import org.kohsuke.randname.RandomNameGenerator
import spark.Spark.*
import java.util.*

fun main(args: Array<String>) {
    val random = Random()
    val nameGen = RandomNameGenerator()

    port(9999)
    before("stats/*") { req, res ->
        res.type("application/json")
        res.header("Access-Control-Allow-Origin", "*")
    }

    get("stats/tree") { req, res ->
        var index = 1
        var courses = emptyList<JsonObject>()
        (0..3).forEach { i ->
            val course = jsonObject(
                    "name" to "Course $i",
                    "type" to "course",
                    "id" to index++
            )
            var subjects = emptyList<JsonObject>()
            (0..3).forEach { j ->
                val subject = jsonObject(
                        "name" to "Subject $i/$j",
                        "type" to "subject",
                        "id" to index++
                )
                var exercises = emptyList<JsonObject>()
                (0..3).forEach { k ->
                    val video = jsonObject(
                            "name" to "Video $i/$j/$k",
                            "type" to "video",
                            "id" to index++
                    )
                    exercises += video
                }
                (0..3).forEach { k ->
                    val exercise = jsonObject(
                            "name" to "WrittenExercise $i/$j/$k",
                            "type" to "writtenexercisegroup",
                            "id" to index++
                    )
                    exercises += exercise
                }
                subject["children"] = jsonArray(exercises)
                subjects += subject
            }
            course["children"] = jsonArray(subjects)
            courses += course
        }
        jsonArray(courses).toString()
    }

    get("stats/students/:course") { req, res ->
        val students = ArrayList<JsonObject>()
        (1..random.nextInt(20)).forEach {
            students += jsonObject(
                    "username" to nameGen.next(),
                    "id" to Math.abs(random.nextInt())
            )
        }
        jsonArray(students).toString()
    }
}

