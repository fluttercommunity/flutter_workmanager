package dev.fluttercommunity.workmanager

import androidx.work.Data
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener

/** Prefix for payload keys stored as native WorkManager [Data] values. */
const val PAYLOAD_PREFIX = "payload_"

/**
 * Prefix for payload keys stored as JSON strings.
 *
 * WorkManager [Data] cannot store nested maps, lists of non-primitive or mixed
 * element types, or null values. Those values are JSON-encoded under this
 * prefix. Keeping a separate prefix (rather than reusing [PAYLOAD_PREFIX])
 * keeps the encoding backward compatible with previously enqueued jobs.
 */
const val JSON_PAYLOAD_PREFIX = "json_payload_"

/**
 * Serializes [dartTask] and [payload] into WorkManager [Data].
 *
 * - Scalars are stored natively under `payload_<key>` (same keys as before).
 * - Homogeneous lists are stored as typed primitive arrays under
 *   `payload_<key>`, replacing the previous behavior that silently dropped
 *   non-String elements.
 * - Nested maps, heterogeneous lists, and null values are JSON-encoded under
 *   `json_payload_<key>` and decoded again when the task runs.
 */
fun buildTaskInputData(
    dartTask: String,
    payload: Map<String, Any?>?,
): Data {
    val builder = Data.Builder().putString(BackgroundWorker.DART_TASK_KEY, dartTask)

    payload?.forEach { (key, value) ->
        when (value) {
            null -> builder.putJsonPayload(key, null)
            is String -> builder.putString("$PAYLOAD_PREFIX$key", value)
            is Boolean -> builder.putBoolean("$PAYLOAD_PREFIX$key", value)
            is Int -> builder.putInt("$PAYLOAD_PREFIX$key", value)
            is Long -> builder.putLong("$PAYLOAD_PREFIX$key", value)
            is Float -> builder.putFloat("$PAYLOAD_PREFIX$key", value)
            is Double -> builder.putDouble("$PAYLOAD_PREFIX$key", value)
            is ByteArray -> builder.putByteArray("$PAYLOAD_PREFIX$key", value)
            is List<*> -> builder.putListPayload(key, value)
            is Map<*, *> -> builder.putJsonPayload(key, value)
            else ->
                throw IllegalArgumentException(
                    "Unsupported payload type for key '$key': ${value::class.java.simpleName}. " +
                        "Consider converting it to a supported type.",
                )
        }
    }

    return builder.build()
}

/**
 * Converts a WorkManager [Data] key-value map back into the payload map that
 * is delivered to the Dart callback.
 *
 * JSON-encoded entries (`json_payload_*`) are decoded back into nested maps and
 * lists; typed arrays are converted to lists.
 */
fun decodePayload(keyValueMap: Map<String, Any?>): Map<String, Any?> {
    val result = LinkedHashMap<String, Any?>()
    keyValueMap.forEach { (key, value) ->
        when {
            key.startsWith(JSON_PAYLOAD_PREFIX) ->
                result[key.removePrefix(JSON_PAYLOAD_PREFIX)] = decodeJson(value)
            key.startsWith(PAYLOAD_PREFIX) ->
                result[key.removePrefix(PAYLOAD_PREFIX)] = normalizeDataValue(value)
        }
    }
    return result
}

private fun Data.Builder.putJsonPayload(
    key: String,
    value: Any?,
): Data.Builder {
    putString("$JSON_PAYLOAD_PREFIX$key", toJsonString(value))
    return this
}

private fun Data.Builder.putListPayload(
    key: String,
    value: List<*>,
): Data.Builder {
    val payloadKey = "$PAYLOAD_PREFIX$key"
    when {
        value.all { it is String } ->
            putStringArray(payloadKey, value.filterIsInstance<String>().toTypedArray())
        value.all { it is Boolean } ->
            putBooleanArray(payloadKey, value.filterIsInstance<Boolean>().toBooleanArray())
        value.all { it is Int } ->
            putIntArray(payloadKey, value.filterIsInstance<Int>().toIntArray())
        value.all { it is Long } ->
            putLongArray(payloadKey, value.filterIsInstance<Long>().toLongArray())
        value.all { it is Float } ->
            putFloatArray(payloadKey, value.filterIsInstance<Float>().toFloatArray())
        value.all { it is Double } ->
            putDoubleArray(payloadKey, value.filterIsInstance<Double>().toDoubleArray())
        else -> putJsonPayload(key, value)
    }
    return this
}

private fun toJsonString(value: Any?): String = jsonValue(value).toString()

private fun jsonValue(value: Any?): Any? =
    when (value) {
        null, is Boolean, is Int, is Long, is Float, is Double, is String -> value
        is Map<*, *> ->
            JSONObject().apply {
                value.forEach { (key, nested) -> put(key.toString(), jsonValue(nested)) }
            }
        is List<*> ->
            JSONArray().apply {
                value.forEach { put(jsonValue(it)) }
            }
        is ByteArray ->
            JSONArray().apply {
                value.forEach { put(it.toInt() and 0xFF) }
            }
        else ->
            throw IllegalArgumentException(
                "Unsupported payload type: ${value::class.java.simpleName}. " +
                    "Consider converting it to a supported type.",
            )
    }

private fun decodeJson(value: Any?): Any? {
    if (value !is String) {
        return value
    }
    return decodeJsonValue(JSONTokener(value).nextValue())
}

private fun decodeJsonValue(value: Any?): Any? =
    when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> {
            val map = LinkedHashMap<String, Any?>()
            value.keys().asSequence().forEach { key -> map[key] = decodeJsonValue(value.get(key)) }
            map
        }
        is JSONArray -> (0 until value.length()).map { decodeJsonValue(value.get(it)) }
        else -> value
    }

private fun normalizeDataValue(value: Any?): Any? =
    when (value) {
        is Array<*> -> value.asList()
        is IntArray -> value.toList()
        is LongArray -> value.toList()
        is FloatArray -> value.toList()
        is DoubleArray -> value.toList()
        is BooleanArray -> value.toList()
        else -> value
    }
