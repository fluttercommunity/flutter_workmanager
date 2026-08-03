package dev.fluttercommunity.workmanager

import android.net.Uri
import dev.fluttercommunity.workmanager.pigeon.ContentUriTrigger
import dev.fluttercommunity.workmanager.pigeon.NetworkType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [26])
class ConstraintsMappingTest {
    @Test
    fun `content uri triggers map to androidx constraints`() {
        val pigeonConstraints =
            dev.fluttercommunity.workmanager.pigeon.Constraints(
                contentUriTriggers =
                    listOf(
                        ContentUriTrigger(
                            uri = "content://media/external/images/media",
                            triggerForDescendants = true,
                        ),
                    ),
            )

        val androidConstraints = pigeonConstraints.toAndroidConstraints()

        assertTrue(androidConstraints.hasContentUriTriggers())
        val trigger = androidConstraints.contentUriTriggers.single()
        assertEquals(Uri.parse("content://media/external/images/media"), trigger.uri)
        assertTrue(trigger.isTriggeredForDescendants)
    }

    @Test
    fun `multiple triggers with mixed descendant flags are preserved`() {
        val pigeonConstraints =
            dev.fluttercommunity.workmanager.pigeon.Constraints(
                contentUriTriggers =
                    listOf(
                        ContentUriTrigger(
                            uri = "content://media/external/images/media",
                            triggerForDescendants = true,
                        ),
                        ContentUriTrigger(
                            uri = "content://com.example.provider/items",
                            triggerForDescendants = false,
                        ),
                    ),
            )

        val androidConstraints = pigeonConstraints.toAndroidConstraints()

        assertEquals(2, androidConstraints.contentUriTriggers.size)
        val byUri = androidConstraints.contentUriTriggers.associateBy { it.uri }
        assertTrue(byUri.getValue(Uri.parse("content://media/external/images/media")).isTriggeredForDescendants)
        assertFalse(byUri.getValue(Uri.parse("content://com.example.provider/items")).isTriggeredForDescendants)
    }

    @Test
    fun `constraints without content uri triggers map no triggers`() {
        val pigeonConstraints =
            dev.fluttercommunity.workmanager.pigeon.Constraints(
                networkType = NetworkType.CONNECTED,
                requiresCharging = true,
            )

        val androidConstraints = pigeonConstraints.toAndroidConstraints()

        assertFalse(androidConstraints.hasContentUriTriggers())
        assertEquals(androidx.work.NetworkType.CONNECTED, androidConstraints.requiredNetworkType)
        assertTrue(androidConstraints.requiresCharging())
    }

    @Test
    fun `content uri triggers require API 24`() {
        // JobScheduler silently drops content URI triggers below Android 7.0 (API 24).
        assertFalse(isContentUriTriggerSupported(sdkInt = 23))
        assertTrue(isContentUriTriggerSupported(sdkInt = 24))
        assertTrue(isContentUriTriggerSupported(sdkInt = 35))
    }
}
