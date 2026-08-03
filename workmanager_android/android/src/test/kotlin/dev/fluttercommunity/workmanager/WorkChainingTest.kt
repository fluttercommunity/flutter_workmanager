package dev.fluttercommunity.workmanager

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.work.ListenableWorker
import androidx.work.Operation
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.impl.WorkManagerImpl
import androidx.work.impl.model.WorkSpec
import androidx.work.testing.WorkManagerTestInitHelper
import dev.fluttercommunity.workmanager.pigeon.BackoffPolicyConfig
import dev.fluttercommunity.workmanager.pigeon.ChainTaskRequest
import dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy
import dev.fluttercommunity.workmanager.pigeon.UniqueWorkChainRequest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Deterministic [ListenableWorker]s so chains can be executed without a Flutter engine. */
private object TestWorkers {
    class Success(
        context: Context,
        params: WorkerParameters,
    ) : Worker(context, params) {
        override fun doWork(): Result = Result.success()
    }

    class Failure(
        context: Context,
        params: WorkerParameters,
    ) : Worker(context, params) {
        override fun doWork(): Result = Result.failure()
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [26])
class WorkChainingTest {
    private lateinit var workManager: WorkManager

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        WorkManagerTestInitHelper.initializeTestWorkManager(context)
        workManager = WorkManager.getInstance(context)
    }

    private fun context() = ApplicationProvider.getApplicationContext<Context>()

    private fun chainRequest(
        uniqueName: String,
        vararg taskNames: String,
        existingWorkPolicy: ExistingWorkPolicy? = null,
        inputData: Map<String?, Any?>? = null,
    ) = UniqueWorkChainRequest(
        uniqueName = uniqueName,
        tasks = taskNames.map { ChainTaskRequest(taskName = it, inputData = inputData) },
        existingWorkPolicy = existingWorkPolicy,
    )

    /** Enqueues a chain and waits until the enqueue operation has completed. */
    private fun enqueue(
        uniqueName: String,
        workerClass: Class<out ListenableWorker>,
        request: UniqueWorkChainRequest,
    ) {
        val operation: Operation =
            WorkManagerWrapper(context(), workerClass).beginUniqueWork(request)
        operation.result.get()
    }

    private fun workSpecs(uniqueName: String): List<WorkSpec> {
        val dao = WorkManagerImpl.getInstance(context()).workDatabase.workSpecDao()
        return dao.getWorkSpecIdAndStatesForName(uniqueName).map { dao.getWorkSpec(it.id)!! }
    }

    private fun specByName(uniqueName: String): Map<String, WorkSpec> =
        workSpecs(uniqueName)
            .mapNotNull { spec ->
                spec.input.getString(BackgroundWorker.DART_TASK_KEY)?.let { it to spec }
            }.toMap()

    private fun infosByName(uniqueName: String): Map<String, WorkInfo> =
        workManager
            .getWorkInfosForUniqueWork(uniqueName)
            .get()
            .associateBy { it.id.toString() }

    /**
     * With the synchronous test executors every eligible step runs inline as
     * soon as its prerequisites complete; this simply waits until every step
     * of the chain has reached a terminal state.
     */
    private fun awaitTerminalStates(uniqueName: String) {
        val deadline = System.currentTimeMillis() + 5_000
        while (System.currentTimeMillis() < deadline) {
            val infos = workManager.getWorkInfosForUniqueWork(uniqueName).get()
            if (infos.isNotEmpty() && infos.all { it.state.isFinished }) {
                return
            }
            Thread.sleep(10)
        }
        error(
            "chain $uniqueName did not finish in time: " +
                workManager.getWorkInfosForUniqueWork(uniqueName).get(),
        )
    }

    @Test
    fun `empty chain is rejected`() {
        val wrapper = WorkManagerWrapper(context())

        val thrown =
            try {
                wrapper.beginUniqueWork(
                    UniqueWorkChainRequest(uniqueName = "chain", tasks = emptyList()),
                )
                null
            } catch (e: IllegalArgumentException) {
                e
            }

        assertEquals("Work chain must contain at least one task", thrown?.message)
    }

    @Test
    fun `chain steps are enqueued in order`() {
        enqueue("chain", TestWorkers.Success::class.java, chainRequest("chain", "step1", "step2", "step3"))

        val byName = specByName("chain")
        assertEquals(setOf("step1", "step2", "step3"), byName.keys)

        val dependencies = WorkManagerImpl.getInstance(context()).workDatabase.dependencyDao()
        assertTrue(dependencies.getPrerequisites(byName.getValue("step1").id).isEmpty())
        assertEquals(listOf(byName.getValue("step1").id), dependencies.getPrerequisites(byName.getValue("step2").id))
        assertEquals(listOf(byName.getValue("step2").id), dependencies.getPrerequisites(byName.getValue("step3").id))
    }

    @Test
    fun `chain steps carry the task name and input data payload convention`() {
        enqueue(
            "chain",
            TestWorkers.Success::class.java,
            chainRequest(
                "chain",
                "step1",
                "step2",
                inputData = mapOf<String?, Any?>("url" to "https://example.com", "count" to 3),
            ),
        )

        val step1 = specByName("chain").getValue("step1")
        assertEquals("step1", step1.input.getString(BackgroundWorker.DART_TASK_KEY))
        assertEquals("https://example.com", step1.input.getString("payload_url"))
        assertEquals(3, step1.input.getInt("payload_count", -1))

        val step2 = specByName("chain").getValue("step2")
        assertEquals("step2", step2.input.getString(BackgroundWorker.DART_TASK_KEY))
        assertEquals("https://example.com", step2.input.getString("payload_url"))
    }

    @Test
    fun `successful steps run in sequence and all complete`() {
        enqueue("chain", TestWorkers.Success::class.java, chainRequest("chain", "step1", "step2"))
        awaitTerminalStates("chain")

        val states = infosByName("chain")
        val byName = specByName("chain")
        assertEquals(WorkInfo.State.SUCCEEDED, states.getValue(byName.getValue("step1").id).state)
        assertEquals(WorkInfo.State.SUCCEEDED, states.getValue(byName.getValue("step2").id).state)
    }

    @Test
    fun `a permanently failed step stops the chain`() {
        enqueue("chain", TestWorkers.Failure::class.java, chainRequest("chain", "step1", "step2", "step3"))
        awaitTerminalStates("chain")

        val states = infosByName("chain")
        val byName = specByName("chain")
        val step1 = states.getValue(byName.getValue("step1").id)
        val step2 = states.getValue(byName.getValue("step2").id)
        val step3 = states.getValue(byName.getValue("step3").id)

        assertEquals(WorkInfo.State.FAILED, step1.state)
        // The remaining steps never run: WorkManager fails/cancels the whole
        // chain as soon as one step fails permanently.
        assertEquals(WorkInfo.State.FAILED, step2.state)
        assertEquals(0, step2.runAttemptCount)
        assertEquals(WorkInfo.State.FAILED, step3.state)
        assertEquals(0, step3.runAttemptCount)
    }

    @Test
    fun `existing work policy applies to the chain`() {
        enqueue("chain", TestWorkers.Success::class.java, chainRequest("chain", "step1", "step2"))
        enqueue(
            "chain",
            TestWorkers.Success::class.java,
            chainRequest(
                "chain",
                "step1b",
                "step2b",
                existingWorkPolicy = ExistingWorkPolicy.REPLACE,
            ),
        )

        val byName = specByName("chain")
        assertEquals(setOf("step1b", "step2b"), byName.keys)
    }

    @Test
    fun `per-step backoff config is applied to the step request`() {
        val request =
            UniqueWorkChainRequest(
                uniqueName = "chain",
                tasks =
                    listOf(
                        ChainTaskRequest(
                            taskName = "step1",
                            backoffPolicy =
                                BackoffPolicyConfig(
                                    backoffPolicy = dev.fluttercommunity.workmanager.pigeon.BackoffPolicy.LINEAR,
                                    backoffDelayMillis = 42_000,
                                ),
                        ),
                    ),
            )

        enqueue("chain", TestWorkers.Success::class.java, request)

        val step1 = specByName("chain").getValue("step1")
        assertEquals(androidx.work.BackoffPolicy.LINEAR, step1.backoffPolicy)
        assertEquals(42_000L, step1.backoffDelayDuration)
    }
}
