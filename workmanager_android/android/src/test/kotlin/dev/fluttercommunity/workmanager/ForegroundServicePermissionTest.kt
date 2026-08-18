package dev.fluttercommunity.workmanager

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceConfig
import dev.fluttercommunity.workmanager.pigeon.ForegroundServiceType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ForegroundServicePermissionTest {
    @Test
    fun `dataSync foreground service throws when the permission is not declared`() {
        // The default plugin manifest does not declare
        // FOREGROUND_SERVICE_DATA_SYNC (it is opt-in, see issue #725), so the
        // merged-manifest check reports the permission as missing and the
        // guard fails loudly.
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

    @Test
    fun `permission check passes when the shortService permission is declared`() {
        // The #731 regression: the plugin's default manifest always declares
        // FOREGROUND_SERVICE_SHORT_SERVICE, so the expedited-work path must
        // pass based on that declaration alone — even when the runtime grant
        // state would report DENIED (Android 16+ can revoke foreground-service
        // permissions). The runtime grant state must not matter.
        val context =
            contextWithRequestedPermissions(
                "android.permission.FOREGROUND_SERVICE",
                "android.permission.FOREGROUND_SERVICE_SHORT_SERVICE",
            )

        // Must not throw.
        requireForegroundServicePermission(
            context,
            "android.permission.FOREGROUND_SERVICE_SHORT_SERVICE",
            "expedited work (setExpedited)",
            "FOREGROUND_SERVICE_SHORT_SERVICE is declared by the plugin by default; " +
                "keep it if you use expedited work (see the workmanager_android " +
                "README, issue #725).",
        )
    }

    @Test
    fun `permission check passes when the dataSync permission is declared`() {
        // Simulates the opt-in manifest swapped in when
        // workmanager.enableDataSyncForegroundService=true declares
        // FOREGROUND_SERVICE_DATA_SYNC.
        val context =
            contextWithRequestedPermissions(
                "android.permission.FOREGROUND_SERVICE",
                "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
                "android.permission.FOREGROUND_SERVICE_SHORT_SERVICE",
            )

        // Must not throw.
        requireForegroundServicePermission(
            context,
            "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
            "foregroundServiceType=dataSync",
            "Add 'workmanager.enableDataSyncForegroundService=true' to your " +
                "gradle.properties (see the workmanager_android README, issue #725).",
        )
    }

    @Test
    fun `permission check throws when the permission is not declared`() {
        // The default plugin manifest does not declare
        // FOREGROUND_SERVICE_DATA_SYNC (it is opt-in, see issue #725), so the
        // guard must fail loudly.
        val context =
            contextWithRequestedPermissions(
                "android.permission.FOREGROUND_SERVICE",
                "android.permission.FOREGROUND_SERVICE_SHORT_SERVICE",
            )

        val exception =
            assertThrows(IllegalStateException::class.java) {
                requireForegroundServicePermission(
                    context,
                    "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
                    "foregroundServiceType=dataSync",
                    "Add 'workmanager.enableDataSyncForegroundService=true' to your " +
                        "gradle.properties (see the workmanager_android README, issue #725).",
                )
            }
        assertTrue(exception.message!!.contains("android.permission.FOREGROUND_SERVICE_DATA_SYNC"))
    }

    @Test
    fun `permission check throws when the permission list is unavailable`() {
        // Defensive edge case: a PackageInfo without requestedPermissions
        // (e.g. from a package manager that did not surface the list) must be
        // treated as "not declared" and fail loudly instead of crashing.
        val context = contextWithRequestedPermissions()

        assertThrows(IllegalStateException::class.java) {
            requireForegroundServicePermission(
                context,
                "android.permission.FOREGROUND_SERVICE_SHORT_SERVICE",
                "expedited work (setExpedited)",
                "FOREGROUND_SERVICE_SHORT_SERVICE is declared by the plugin by default; " +
                    "keep it if you use expedited work (see the workmanager_android " +
                    "README, issue #725).",
            )
        }
    }

    /**
     * Returns a mocked [Context] whose package manager reports the given
     * permissions as the manifest's requestedPermissions. Mirrors what
     * [requireForegroundServicePermission] reads via
     * `getPackageInfo(packageName, GET_PERMISSIONS)`.
     */
    private fun contextWithRequestedPermissions(vararg permissions: String): Context {
        val packageInfo =
            PackageInfo().apply {
                packageName = "com.example.app"
                requestedPermissions = if (permissions.isEmpty()) null else permissions
            }
        val packageManager = mock<PackageManager>()
        whenever(packageManager.getPackageInfo("com.example.app", PackageManager.GET_PERMISSIONS))
            .thenReturn(packageInfo)
        val context = mock<Context>()
        whenever(context.packageName).thenReturn("com.example.app")
        whenever(context.packageManager).thenReturn(packageManager)
        return context
    }
}
