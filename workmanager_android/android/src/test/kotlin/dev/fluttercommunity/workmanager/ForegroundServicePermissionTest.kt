package dev.fluttercommunity.workmanager

import android.content.pm.ServiceInfo
import org.robolectric.RuntimeEnvironment
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceConfig
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ForegroundServicePermissionTest {
    @Test
    fun `dataSync foreground service throws when the permission is not declared`() {
        // The default plugin manifest does not declare
        // FOREGROUND_SERVICE_DATA_SYNC (it is opt-in, see issue #725), so
        // checkPermission reports DENIED and the guard fails loudly.
        val config =
            ForegroundServiceConfig(
                notificationTitle = "Syncing",
                notificationText = "Uploading 42 files",
                foregroundServiceType = ForegroundServiceType.DATA_SYNC,
            )

        assertThrows(IllegalStateException::class.java) {
            createForegroundInfo(RuntimeEnvironment.getApplication(), config)
        }
    }

    @Test
    fun `shortService foreground service builds without the dataSync permission`() {
        // FOREGROUND_SERVICE_SHORT_SERVICE is always declared by the plugin,
        // so the shortService path must not require the opt-in permission.
        val config =
            ForegroundServiceConfig(
                notificationTitle = "Task",
                notificationText = "Working",
                foregroundServiceType = ForegroundServiceType.SHORT_SERVICE,
            )

        val info = createForegroundInfo(RuntimeEnvironment.getApplication(), config)
        assertEquals(
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE.toLong(),
            info.foregroundServiceType.toLong(),
        )
    }
}
