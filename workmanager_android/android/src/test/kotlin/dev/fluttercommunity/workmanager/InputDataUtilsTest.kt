package dev.fluttercommunity.workmanager

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class InputDataUtilsTest {
    @Test
    fun `scalar payload values are stored and decoded natively`() {
        val payload =
            mapOf<String, Any?>(
                "string" to "value",
                "boolean" to true,
                "int" to 42,
                "long" to 9_000_000_000L,
                "double" to 3.14,
                "float" to 1.5f,
            )

        val data = buildTaskInputData("task", payload)
        val decoded = decodePayload(data.keyValueMap)

        assertEquals(payload, decoded)
    }

    @Test
    fun `homogeneous string list keeps legacy key and round-trips`() {
        val payload = mapOf<String, Any?>("list" to listOf("a", "b", "c"))

        val data = buildTaskInputData("task", payload)

        // Migration care: string lists keep the legacy payload_ key, so
        // previously enqueued jobs behave exactly as before.
        assertTrue(data.keyValueMap.containsKey("payload_list"))
        assertTrue(data.keyValueMap.keys.none { it.startsWith(JSON_PAYLOAD_PREFIX) })
        assertEquals(listOf("a", "b", "c"), decodePayload(data.keyValueMap)["list"])
    }

    @Test
    fun `homogeneous int list round-trips without data loss`() {
        val payload = mapOf<String, Any?>("list" to listOf(1, 2, 3))

        val data = buildTaskInputData("task", payload)
        val decoded = decodePayload(data.keyValueMap)

        assertTrue(data.keyValueMap.keys.none { it.startsWith(JSON_PAYLOAD_PREFIX) })
        assertEquals(listOf(1, 2, 3), decoded["list"])
    }

    @Test
    fun `homogeneous long list round-trips without data loss`() {
        val payload = mapOf<String, Any?>("list" to listOf(1L, 2L, 3L))

        val data = buildTaskInputData("task", payload)

        assertEquals(listOf(1L, 2L, 3L), decodePayload(data.keyValueMap)["list"])
    }

    @Test
    fun `homogeneous double and boolean lists round-trip`() {
        val payload =
            mapOf<String, Any?>(
                "doubles" to listOf(1.5, 2.5),
                "bools" to listOf(true, false),
            )

        val data = buildTaskInputData("task", payload)
        val decoded = decodePayload(data.keyValueMap)

        assertEquals(listOf(1.5, 2.5), decoded["doubles"])
        assertEquals(listOf(true, false), decoded["bools"])
    }

    @Test
    fun `mixed lists are JSON-encoded and decoded without data loss`() {
        val payload =
            mapOf<String, Any?>(
                "mixed" to listOf("a", 1, true, 2.5),
                "empty" to emptyList<String>(),
            )

        val data = buildTaskInputData("task", payload)

        assertTrue(data.keyValueMap.containsKey("json_payload_mixed"))
        val mixed = decodePayload(data.keyValueMap)["mixed"] as List<*>
        assertEquals(4, mixed.size)
        assertEquals("a", mixed[0])
        assertEquals(1, (mixed[1] as Number).toInt())
        assertEquals(true, mixed[2])
        assertEquals(2.5, (mixed[3] as Number).toDouble(), 0.0001)
        assertEquals(emptyList<Any>(), decodePayload(data.keyValueMap)["empty"])
    }

    @Test
    fun `nested maps are JSON-encoded and decoded back into maps`() {
        val payload =
            mapOf<String, Any?>(
                "user" to
                    mapOf(
                        "name" to "Ada",
                        "roles" to listOf("admin", "dev"),
                        "meta" to mapOf("active" to true),
                    ),
            )

        val data = buildTaskInputData("task", payload)

        assertTrue(data.keyValueMap.containsKey("json_payload_user"))
        assertEquals(payload, decodePayload(data.keyValueMap))
    }

    @Test
    fun `null values are preserved through JSON encoding`() {
        val payload = mapOf<String, Any?>("nullable" to null)

        val data = buildTaskInputData("task", payload)
        val decoded = decodePayload(data.keyValueMap)

        assertTrue(decoded.containsKey("nullable"))
        assertEquals(null, decoded["nullable"])
    }

    @Test
    fun `byte arrays round-trip`() {
        val payload = mapOf<String, Any?>("bytes" to byteArrayOf(1, 2, 3))

        val data = buildTaskInputData("task", payload)
        val decoded = decodePayload(data.keyValueMap)["bytes"]

        when (decoded) {
            is ByteArray -> assertTrue(decoded.contentEquals(byteArrayOf(1, 2, 3)))
            is List<*> -> assertEquals(listOf<Byte>(1, 2, 3), decoded)
            else -> throw AssertionError("Unexpected decoded byte value: $decoded")
        }
    }

    @Test
    fun `unsupported payload values still fail fast with a clear message`() {
        val payload = mapOf<String, Any?>("obj" to Any())

        val exception = runCatching { buildTaskInputData("task", payload) }.exceptionOrNull()

        assertTrue(exception is IllegalArgumentException)
        assertTrue(exception!!.message!!.contains("Unsupported payload type for key 'obj'"))
    }
}
