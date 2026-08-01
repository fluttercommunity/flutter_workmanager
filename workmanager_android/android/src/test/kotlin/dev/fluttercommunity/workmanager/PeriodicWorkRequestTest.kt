package dev.fluttercommunity.workmanager

import androidx.work.Constraints
import org.junit.Assert.assertEquals
import org.junit.Test

class PeriodicWorkRequestTest {
    @Test
    fun `without explicit flex the first run honors the initial delay`() {
        val request =
            createPeriodicWorkRequest(
                taskName = "task",
                inputData = null,
                frequencySeconds = 900,
                flexIntervalSeconds = null,
                initialDelaySeconds = 120,
                constraints = Constraints.NONE,
                backoffPolicy = null,
                tag = null,
            )

        // flex == interval means no flex window, so the first run is scheduled
        // at enqueueTime + initialDelay (instead of being shifted by
        // interval - flex).
        assertEquals(900_000L, request.workSpec.intervalDuration)
        assertEquals(request.workSpec.intervalDuration, request.workSpec.flexDuration)
        assertEquals(120_000L, request.workSpec.initialDelay)
    }

    @Test
    fun `explicit flex interval is applied`() {
        val request =
            createPeriodicWorkRequest(
                taskName = "task",
                inputData = null,
                frequencySeconds = 900,
                flexIntervalSeconds = 300,
                initialDelaySeconds = 0,
                constraints = Constraints.NONE,
                backoffPolicy = null,
                tag = null,
            )

        assertEquals(900_000L, request.workSpec.intervalDuration)
        assertEquals(300_000L, request.workSpec.flexDuration)
    }
}
