package dev.fluttercommunity.workmanager

import androidx.work.Constraints
import androidx.work.Data
import androidx.work.WorkInfo
import dev.fluttercommunity.workmanager.pigeon.WorkState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class WorkInfoMappingTest {
    private fun workInfo(
        state: WorkInfo.State,
        tags: Set<String> = setOf("tag-b", "tag-a"),
        taskName: String? = "dart-task",
        periodic: Boolean = false,
    ): WorkInfo {
        val data = Data.Builder().putString(BackgroundWorker.DART_TASK_KEY, taskName).build()
        return if (periodic) {
            WorkInfo(
                UUID.randomUUID(),
                state,
                tags,
                data,
                Data.EMPTY,
                0,
                0,
                Constraints.NONE,
                0L,
                WorkInfo.PeriodicityInfo(900_000L, 0L),
            )
        } else {
            WorkInfo(UUID.randomUUID(), state, tags, data)
        }
    }

    @Test
    fun `enqueued work maps to scheduled state`() {
        val data = workInfo(WorkInfo.State.ENQUEUED).toWorkInfoData("unique-name")

        assertEquals("unique-name", data.uniqueName)
        assertEquals(WorkState.SCHEDULED, data.state)
        assertFalse(data.isPeriodic)
        assertEquals("dart-task", data.taskName)
        assertEquals(listOf("tag-a", "tag-b"), data.tags)
        assertNull(data.lastFinishedAtMillis)
    }

    @Test
    fun `blocked work maps to scheduled state`() {
        assertEquals(WorkState.SCHEDULED, workInfo(WorkInfo.State.BLOCKED).toWorkInfoData("u").state)
    }

    @Test
    fun `running work maps to running state`() {
        assertEquals(WorkState.RUNNING, workInfo(WorkInfo.State.RUNNING).toWorkInfoData("u").state)
    }

    @Test
    fun `succeeded work maps to succeeded state`() {
        assertEquals(WorkState.SUCCEEDED, workInfo(WorkInfo.State.SUCCEEDED).toWorkInfoData("u").state)
    }

    @Test
    fun `failed work maps to failed state`() {
        assertEquals(WorkState.FAILED, workInfo(WorkInfo.State.FAILED).toWorkInfoData("u").state)
    }

    @Test
    fun `cancelled work maps to cancelled state`() {
        assertEquals(WorkState.CANCELLED, workInfo(WorkInfo.State.CANCELLED).toWorkInfoData("u").state)
    }

    @Test
    fun `periodic work is reported via periodicity info`() {
        val data = workInfo(WorkInfo.State.ENQUEUED, periodic = true).toWorkInfoData("u")

        assertTrue(data.isPeriodic)
    }

    @Test
    fun `missing task name stays null`() {
        val info =
            WorkInfo(
                UUID.randomUUID(),
                WorkInfo.State.ENQUEUED,
                setOf("tag"),
                Data.EMPTY,
            )

        assertNull(info.toWorkInfoData("u").taskName)
    }
}
