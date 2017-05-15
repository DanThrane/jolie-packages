package dk.thrane.jolie

import org.junit.Test
import java.io.File
import org.junit.Assert.*
import org.hamcrest.CoreMatchers.*

class TeamTest {
    @Test
    fun testCreatingTeamAndListingMember() {
        JPM.withRegistry {
            val teamName = "foo"
            registerAndAuthenticate(name = "MyUser", withRandomSuffix = false)

            val folder = File(".")
            JPM(folder, listOf("team", "create", teamName)).runAndAssert()
            assertTeamMembers(teamName, 1, "myuser")
        }
    }

    @Test
    fun testDuplicateTeamNames() {
        JPM.withRegistry {
            val teamName = "foo"
            registerAndAuthenticate()

            val folder = File(".")
            JPM(folder, listOf("team", "create", teamName)).runAndAssert()
            val result = JPM(folder, listOf("team", "create", teamName)).run()
            assertNonInternalFailure(result)
        }
    }

    @Test
    fun testPromotingAndDemoting() {
        JPM.withRegistry {
            val team = "foo"
            val user = "User"
            val admin = "Admin"
            registerAndAuthenticate(name = user, withRandomSuffix = false)
            registerAndAuthenticate(name = admin, withRandomSuffix = false)

            val folder = File(".")
            JPM(folder, listOf("team", "create", team)).runAndAssert()

            reauthenticate(user)
            val listAsNormalUser = JPM(folder, listOf("team", "list")).run()
            assertNonInternalFailure(listAsNormalUser)

            reauthenticate(admin)
            JPM(folder, listOf("team", "add", team, user)).runAndAssert()
            assertTeamMembers(team, 2, user, admin)

            reauthenticate(user)
            val listAsNormalMember = JPM(folder, listOf("team", "list", team)).run()
            assertNonInternalFailure(listAsNormalMember)

            reauthenticate(admin)
            JPM(folder, listOf("team", "promote", team, user)).runAndAssert()

            reauthenticate(user)
            assertTeamMembers(team, 2, user, admin)

            reauthenticate(admin)
            JPM(folder, listOf("team", "demote", team, user)).runAndAssert()

            reauthenticate(user)
            val listAsDemoted = JPM(folder, listOf("team", "list", team)).run()
            assertNonInternalFailure(listAsDemoted)
        }
    }

    @Test
    fun testAddAndRemoveMembers() {
        JPM.withRegistry {
            val team = "foo"
            val user = "user"
            val admin = "admin"
            registerAndAuthenticate(name = user, withRandomSuffix = false)
            registerAndAuthenticate(name = admin, withRandomSuffix = false)

            val folder = File(".")
            JPM(folder, listOf("team", "create", team)).runAndAssert()
            assertTeamMembers(team, 1, admin)

            JPM(folder, listOf("team", "add", team, user)).runAndAssert()
            assertTeamMembers(team, 2, user, admin)
        }
    }

    private fun assertNonInternalFailure(result: JPMResult) {
        assertNotEquals(0, result.exitCode)
        assertNotEquals(-1, result.exitCode)
        assertNotEquals(500, result.exitCode)
    }

    private fun assertTeamMembers(teamName: String, size: Int, vararg users: String) {
        val result = JPM(File("."), listOf("team", "list", teamName)).runAndAssert()
        assertThat(result.stdOut.first().split(" "), hasItem("$size"))
        assertThat(result.stdOut, hasItems(*users.map { it.toLowerCase() }.map(::containsString).toTypedArray()))
    }
}

