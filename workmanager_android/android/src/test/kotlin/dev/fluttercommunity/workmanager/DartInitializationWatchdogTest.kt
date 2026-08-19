package dev.fluttercommunity.workmanager

import android.os.Handler
import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DartInitializationWatchdogTest {
    private val mainLooper = Looper.getMainLooper()

    private fun createWatchdog(onTimeout: () -> Unit): DartInitializationWatchdog =
        DartInitializationWatchdog(
            handler = Handler(mainLooper),
            timeoutMillis = TIMEOUT_MILLIS,
            timeoutAction = onTimeout,
        )

    private fun advance(millis: Long) {
        shadowOf(mainLooper).idleFor(Duration.ofMillis(millis))
    }

    @Test
    fun `timeout action fires when the acknowledgement does not arrive`() {
        var fired = 0
        val watchdog = createWatchdog { fired++ }

        watchdog.arm()

        advance(TIMEOUT_MILLIS - 1)
        assertEquals(0, fired)

        advance(1)
        assertEquals(1, fired)
    }

    @Test
    fun `disarm before the timeout prevents the action`() {
        var fired = 0
        val watchdog = createWatchdog { fired++ }

        watchdog.arm()
        watchdog.disarm()

        advance(TIMEOUT_MILLIS + 1)
        assertEquals(0, fired)
    }

    @Test
    fun `action fires at most once`() {
        var fired = 0
        val watchdog = createWatchdog { fired++ }

        watchdog.arm()
        advance(TIMEOUT_MILLIS + 1)
        advance(TIMEOUT_MILLIS + 1)
        assertEquals(1, fired)
    }

    @Test
    fun `double arm does not schedule a second countdown`() {
        var fired = 0
        val watchdog = createWatchdog { fired++ }

        watchdog.arm()
        watchdog.arm()
        advance(TIMEOUT_MILLIS + 1)
        assertEquals(1, fired)
    }

    @Test
    fun `disarm after the timeout fired is a no-op`() {
        var fired = 0
        val watchdog = createWatchdog { fired++ }

        watchdog.arm()
        advance(TIMEOUT_MILLIS + 1)
        watchdog.disarm()
        assertEquals(1, fired)
    }

    @Test
    fun `re-arming after a timeout restarts the countdown`() {
        var fired = 0
        val watchdog = createWatchdog { fired++ }

        watchdog.arm()
        advance(TIMEOUT_MILLIS + 1)
        assertEquals(1, fired)

        // The watchdog is one-shot per arm; a fresh arm (e.g. a retried
        // startWork) must observe the timeout again.
        watchdog.arm()
        advance(TIMEOUT_MILLIS - 1)
        assertEquals(1, fired)
        advance(1)
        assertEquals(2, fired)
    }

    @Test
    fun `timeout action is invoked on the handler thread`() {
        val threadName = mutableListOf<String>()
        val watchdog = createWatchdog { threadName.add(Thread.currentThread().name) }

        watchdog.arm()
        advance(TIMEOUT_MILLIS + 1)

        assertTrue(threadName.isNotEmpty())
        assertEquals(Looper.getMainLooper().thread.name, threadName.single())
    }

    private companion object {
        const val TIMEOUT_MILLIS = 30_000L
    }
}
