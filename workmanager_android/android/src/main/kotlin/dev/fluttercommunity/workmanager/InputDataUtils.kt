package dev.fluttercommunity.workmanager

import androidx.work.Data
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceConfig
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceType
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
 * Key under which the foreground service configuration is stored in
 * WorkManager [Data]. Kept separate from the user payload so it is never
 * delivered to the Dart callback and never collides with user keys.
 */
const val FOREGROUND_SERVICE_CONFIG_KEY =
    "dev.fluttercommunity.workmanager.FOREGROUND_SERVICE_CONFIG"

/**
 * Key under which the task's unique name is stored in WorkManager [Data].
 *
 * The unique name is only known at enqueue time, so it is persisted next to
 * the Dart task name. The worker reads it back when it runs; it is used to
 * key progress updates (WorkManager stores progress per unique work name)
 * and to route progress events back to the app. It is never delivered to the
 * Dart callback.
 */
const val UNIQUE_NAME_KEY = "dev.fluttercommunity.workmanager.UNIQUE_NAME"

/**
 * Serializes [dartTask], the task's [uniqueName] and [payload] into
 * WorkManager [Data].
 *
 * - Scalars are stored natively under `payload_<key>` (same keys as before).
 * - Homogeneous lists are stored as typed primitive arrays under
 *   `payload_<key>`, replacing the previous behavior that silently dropped
 *   non-String elements.
 * - Nested maps, heterogeneous lists, and null values are JSON-encoded under
 *   `json_payload_<key>` and decoded again when the task runs.
 * - An optional [foregroundServiceConfig] is JSON-encoded under
 *   [FOREGROUND_SERVICE_CONFIG_KEY].
 * - An optional [uniqueName] is stored under [UNIQUE_NAME_KEY].
 */
fun buildTaskInputData(
    dartTask: String,
    payload: Map<String, Any?>?,
    foregroundServiceConfig: ForegroundServiceConfig? = null,
    uniqueName: String? = null,
): Data {
    val builder = Data.Builder().putString(BackgroundWorker.DART_TASK_KEY, dartTask)

    uniqueName?.let { builder.putString(UNIQUE_NAME_KEY, it) }

    foregroundServiceConfig?.let {
        builder.putString(FOREGROUND_SERVICE_CONFIG_KEY, encodeForegroundServiceConfig(it))
    }

    payload?.forEach { (key, value) ->
        builder.putPayloadValue(key, value)
    }

    return builder.build()
}

/**
 * Encodes a progress map into WorkManager [Data] using the same encoding as
 * the task payload (see [buildTaskInputData]), so the progress reported by a
 * task round-trips through [decodePayload] unchanged.
 *
 * Keys that are null are skipped, mirroring how input data is normalized
 * before it is stored.
 */
fun encodeProgressData(progress: Map<String?, Any?>?): Data {
    val builder = Data.Builder()
    progress?.forEach { (key, value) ->
        if (key != null) {
            builder.putPayloadValue(key, value)
        }
    }
    return builder.build()
}

private fun Data.Builder.putPayloadValue(
    key: String,
    value: Any?,
): Data.Builder {
    when (value) {
        null -> putJsonPayload(key, null)
        is String -> putString("$PAYLOAD_PREFIX$key", value)
        is Boolean -> putBoolean("$PAYLOAD_PREFIX$key", value)
        is Int -> putInt("$PAYLOAD_PREFIX$key", value)
        is Long -> putLong("$PAYLOAD_PREFIX$key", value)
        is Float -> putFloat("$PAYLOAD_PREFIX$key", value)
        is Double -> putDouble("$PAYLOAD_PREFIX$key", value)
        is ByteArray -> putByteArray("$PAYLOAD_PREFIX$key", value)
        is List<*> -> putListPayload(key, value)
        is Map<*, *> -> putJsonPayload(key, value)
        else ->
            throw IllegalArgumentException(
                "Unsupported payload type for key '$key': ${value::class.java.simpleName}. " +
                    "Consider converting it to a supported type.",
            )
    }
    return this
}

/** Encodes a [ForegroundServiceConfig] as a JSON string for WorkManager [Data]. */
fun encodeForegroundServiceConfig(config: ForegroundServiceConfig): String =
    JSONObject()
        .apply {
            config.notificationTitle?.let { put("notificationTitle", it) }
            config.notificationText?.let { put("notificationText", it) }
            config.notificationChannelId?.let { put("notificationChannelId", it) }
            config.notificationChannelName?.let { put("notificationChannelName", it) }
            config.notificationId?.let { put("notificationId", it) }
            config.foregroundServiceType?.let { put("foregroundServiceType", it.name) }
        }.toString()

/** Decodes a [ForegroundServiceConfig] from WorkManager [Data], or `null` when absent. */
fun decodeForegroundServiceConfig(data: Data?): ForegroundServiceConfig? =
    data?.getString(FOREGROUND_SERVICE_CONFIG_KEY)?.let(::decodeForegroundServiceConfig)

/** Decodes a [ForegroundServiceConfig] from its JSON representation. */
fun decodeForegroundServiceConfig(json: String): ForegroundServiceConfig =
    JSONObject(json).let { obj ->
        ForegroundServiceConfig(
            notificationTitle = obj.optStringOrNull("notificationTitle"),
            notificationText = obj.optStringOrNull("notificationText"),
            notificationChannelId = obj.optStringOrNull("notificationChannelId"),
            notificationChannelName = obj.optStringOrNull("notificationChannelName"),
            notificationId = obj.takeIf { it.has("notificationId") }?.getLong("notificationId"),
            foregroundServiceType =
                obj
                    .optStringOrNull("foregroundServiceType")
                    ?.let { ForegroundServiceType.valueOf(it) },
        )
    }

private fun JSONObject.optStringOrNull(key: String): String? = if (isNull(key)) null else optString(key)

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
