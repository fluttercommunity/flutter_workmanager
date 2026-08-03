package dev.fluttercommunity.workmanager

import androidx.work.OutOfQuotaPolicy
import dev.fluttercommunity.workmanager.pigeon.OneOffTaskRequest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [26])
class ExpeditedWorkRequestTest {
    private fun request(
        expedited: Boolean?,
        outOfQuotaPolicy: dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy? = null,
    ) = OneOffTaskRequest(
        uniqueName = "unique",
        taskName = "task",
        expedited = expedited,
        outOfQuotaPolicy = outOfQuotaPolicy,
    )

    @Test
    fun `expedited request is scheduled as expedited with default policy`() {
        val workRequest = createOneOffWorkRequest(request(expedited = true))

        assertTrue(workRequest.workSpec.expedited)
        assertEquals(
            OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST,
            workRequest.workSpec.outOfQuotaPolicy,
        )
    }

    @Test
    fun `expedited request keeps an explicitly provided out of quota policy`() {
        val workRequest =
            createOneOffWorkRequest(
                request(
                    expedited = true,
                    outOfQuotaPolicy =
                        dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy.DROP_WORK_REQUEST,
                ),
            )

        assertTrue(workRequest.workSpec.expedited)
        assertEquals(OutOfQuotaPolicy.DROP_WORK_REQUEST, workRequest.workSpec.outOfQuotaPolicy)
    }

    @Test
    fun `non-expedited request is not expedited`() {
        val workRequest = createOneOffWorkRequest(request(expedited = false))

        assertFalse(workRequest.workSpec.expedited)
    }

    @Test
    fun `null expedited field defaults to non-expedited`() {
        val workRequest = createOneOffWorkRequest(request(expedited = null))

        assertFalse(workRequest.workSpec.expedited)
    }

    @Test
    fun `out of quota policy without expedited flag does not expedite the request`() {
        val workRequest =
            createOneOffWorkRequest(
                request(
                    expedited = false,
                    outOfQuotaPolicy =
                        dev.fluttercommunity.workmanager.pigeon.OutOfQuotaPolicy.DROP_WORK_REQUEST,
                ),
            )

        // OutOfQuotaPolicy only takes effect for expedited work.
        assertFalse(workRequest.workSpec.expedited)
    }
}
