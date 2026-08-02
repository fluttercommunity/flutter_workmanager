package dev.fluttercommunity.workmanager

import dev.fluttercommunity.workmanager.pigeon.TaskStatus
import org.junit.Assert.assertEquals
import org.junit.Test

class StopReasonUtilsTest {
    @Test
    fun `app cancellations map to the cancelled status`() {
        assertEquals(TaskStatus.CANCELLED, StopReasonUtils.toTaskStatus(StopReasonUtils.STOP_REASON_CANCELLED_BY_APP))
        assertEquals(TaskStatus.CANCELLED, StopReasonUtils.toTaskStatus(StopReasonUtils.STOP_REASON_SYSTEM_IGNORED_CANCELLED_BY_APP))
    }

    @Test
    fun `other stop reasons keep the failed status`() {
        assertEquals(TaskStatus.FAILED, StopReasonUtils.toTaskStatus(StopReasonUtils.STOP_REASON_UNKNOWN))
        assertEquals(TaskStatus.FAILED, StopReasonUtils.toTaskStatus(1))
        assertEquals(TaskStatus.FAILED, StopReasonUtils.toTaskStatus(2))
        assertEquals(TaskStatus.FAILED, StopReasonUtils.toTaskStatus(5))
        assertEquals(TaskStatus.FAILED, StopReasonUtils.toTaskStatus(99))
    }
}
