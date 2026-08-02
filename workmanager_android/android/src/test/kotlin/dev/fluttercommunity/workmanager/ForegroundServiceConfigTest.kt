package dev.fluttercommunity.workmanager

import androidx.work.Data
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceConfig
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ForegroundServiceConfigTest {
    @Test
    fun `config round-trips through WorkManager data`() {
        val config =
            ForegroundServiceConfig(
                notificationTitle = "Syncing",
                notificationText = "Uploading 42 files",
                notificationChannelId = "uploads",
                notificationChannelName = "Uploads",
                notificationId = 7,
                foregroundServiceType = ForegroundServiceType.SHORT_SERVICE,
            )

        val data = Data.Builder().putString(FOREGROUND_SERVICE_CONFIG_KEY, encodeForegroundServiceConfig(config)).build()

        assertEquals(config, decodeForegroundServiceConfig(data))
    }

    @Test
    fun `config is embedded in task input data under the reserved key`() {
        val config = ForegroundServiceConfig(notificationTitle = "Syncing")

        val data = buildTaskInputData("task", payload = null, foregroundServiceConfig = config)

        assertEquals(
            config,
            decodeForegroundServiceConfig(data),
        )
        // The reserved key must not leak into the user-facing payload.
        assertNull(decodePayload(data.keyValueMap)[FOREGROUND_SERVICE_CONFIG_KEY])
    }

    @Test
    fun `payload-only input data has no foreground config`() {
        val data = buildTaskInputData("task", payload = mapOf("key" to "value"))

        assertNull(decodeForegroundServiceConfig(data))
    }

    @Test
    fun `periodic work request embeds the foreground config`() {
        val config = ForegroundServiceConfig(notificationTitle = "Syncing")

        val request =
            createPeriodicWorkRequest(
                taskName = "task",
                inputData = null,
                foregroundServiceConfig = config,
                frequencySeconds = 900,
                flexIntervalSeconds = null,
                initialDelaySeconds = 0,
                constraints = androidx.work.Constraints.NONE,
                backoffPolicy = null,
                tag = null,
            )

        assertEquals(config, decodeForegroundServiceConfig(request.workSpec.input))
    }

    @Test
    fun `null fields in the JSON config decode back as null`() {
        val json = """{"notificationTitle":"Only a title"}"""

        val config = decodeForegroundServiceConfig(json)

        assertEquals("Only a title", config.notificationTitle)
        assertNull(config.notificationText)
        assertNull(config.foregroundServiceType)
    }
}
