package dev.fluttercommunity.workmanager

import androidx.work.Data
import androidx.work.ForegroundUpdater
import androidx.work.ProgressUpdater
import androidx.work.WorkerFactory
import androidx.work.WorkerParameters
import androidx.work.WorkerParameters.RuntimeExtras
import androidx.work.impl.utils.taskexecutor.TaskExecutor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.UUID
import java.util.concurrent.Executor
import kotlin.coroutines.EmptyCoroutineContext

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [26])
class ProgressUpdateTest {
    @Test
    fun `unique name is persisted in the worker data`() {
        val data = buildTaskInputData("task", payload = null, uniqueName = "my-unique-task")

        assertEquals("my-unique-task", data.getString(UNIQUE_NAME_KEY))
    }

    @Test
    fun `unique name is absent when not provided`() {
        val data = buildTaskInputData("task", payload = null)

        assertNull(data.getString(UNIQUE_NAME_KEY))
    }

    @Test
    fun `scalar progress values are stored natively`() {
        val progress =
            mapOf<String?, Any?>(
                "progress" to 0.5,
                "processed" to 12,
                "stage" to "uploading",
            )

        val data = encodeProgressData(progress)

        assertEquals(0.5, data.getDouble("payload_progress", 0.0), 0.0)
        assertEquals(12, data.getInt("payload_processed", 0))
        assertEquals("uploading", data.getString("payload_stage"))
    }

    @Test
    fun `nested progress values are JSON-encoded and round-trip`() {
        val progress =
            mapOf<String?, Any?>(
                "counts" to mapOf("done" to 3, "total" to 10),
                "history" to listOf(1, 2, 3),
            )

        val data = encodeProgressData(progress)
        val decoded = decodePayload(data.keyValueMap)

        assertEquals(progress, decoded)
    }

    @Test
    fun `progress round-trips through the payload encoding`() {
        val progress =
            mapOf<String?, Any?>(
                "progress" to 0.25,
                "message" to "downloading",
                "tags" to listOf("a", "b"),
            )

        val decoded = decodePayload(encodeProgressData(progress).keyValueMap)

        assertEquals(progress, decoded)
    }

    @Test
    fun `null progress keys are skipped`() {
        val data = encodeProgressData(mapOf<String?, Any?>(null to "dropped", "kept" to 1))

        assertFalse(data.keyValueMap.containsKey("dropped"))
        assertTrue(data.keyValueMap.containsKey("payload_kept"))
        assertEquals(mapOf<String, Any?>("kept" to 1), decodePayload(data.keyValueMap))
    }

    @Test
    fun `reportProgress persists the encoded progress data through WorkManager`() {
        val progressUpdater = mock<ProgressUpdater>()
        val worker =
            BackgroundWorker(
                RuntimeEnvironment.getApplication(),
                workerParameters(
                    inputData = mapOf(UNIQUE_NAME_KEY to "my-unique-task"),
                    progressUpdater = progressUpdater,
                ),
            )

        worker.reportProgress(mapOf("progress" to 0.75))

        // setProgressAsync routes through the worker's ProgressUpdater; the
        // Data it receives must be the encoded progress map.
        val dataCaptor = argumentCaptor<Data>()
        verify(progressUpdater).updateProgress(any(), any(), dataCaptor.capture())
        assertEquals(0.75, dataCaptor.firstValue.getDouble("payload_progress", 0.0), 0.0)
    }

    private fun workerParameters(
        inputData: Map<String, Any?>,
        progressUpdater: ProgressUpdater,
    ): WorkerParameters {
        val dataBuilder = Data.Builder()
        inputData.forEach { (key, value) -> dataBuilder.putString(key, value as String) }
        return WorkerParameters(
            UUID.randomUUID(),
            dataBuilder.build(),
            emptyList(),
            RuntimeExtras(),
            0,
            0,
            Executor { it.run() },
            EmptyCoroutineContext,
            mock<TaskExecutor>(),
            mock<WorkerFactory>(),
            progressUpdater,
            mock<ForegroundUpdater>(),
        )
    }
}
