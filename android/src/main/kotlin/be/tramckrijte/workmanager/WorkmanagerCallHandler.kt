package be.tramckrijte.workmanager

import android.content.Context
import androidx.work.*
import be.tramckrijte.workmanager.BackgroundWorker.Companion.DART_TASK_KEY
import be.tramckrijte.workmanager.BackgroundWorker.Companion.IS_IN_DEBUG_MODE_KEY
import be.tramckrijte.workmanager.BackgroundWorker.Companion.PAYLOAD_KEY
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

private fun Context.workManager() = WorkManager.getInstance(this)
private fun MethodChannel.Result.success() = success(true)

private interface CallHandler<T : WorkManagerCall> {
    fun handle(context: Context, convertedCall: T, result: MethodChannel.Result)
}

class WorkmanagerCallHandler(private val ctx: Context) {
    fun handle(call: MethodCall, result: MethodChannel.Result) =
            when (val extractedCall = Extractor.extractWorkManagerCallFromRawMethodName(call)) {
                is WorkManagerCall.Initialize -> InitializeHandler.handle(ctx, extractedCall, result)
                is WorkManagerCall.RegisterTask -> RegisterTaskHandler.handle(ctx, extractedCall, result)
                is WorkManagerCall.CancelTask -> UnregisterTaskHandler.handle(ctx, extractedCall, result)
                is WorkManagerCall.Unknown -> UnknownTaskHandler.handle(ctx, extractedCall, result)
            }
}

private object InitializeHandler : CallHandler<WorkManagerCall.Initialize> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.Initialize, result: MethodChannel.Result) {
        SharedPreferenceHelper.saveCallbackDispatcherHandleKey(context, convertedCall.callbackDispatcherHandleKey)
        result.success()
    }
}

private object RegisterTaskHandler : CallHandler<WorkManagerCall.RegisterTask> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.RegisterTask, result: MethodChannel.Result) {
        if (!SharedPreferenceHelper.hasCallbackHandle(context)) {
            result.error(
                    "1",
                    "You have not properly initialized the Flutter WorkManager Package. " +
                            "You should ensure you have called the 'initialize' function first! " +
                            "Example: \n" +
                            "\n" +
                            "`Workmanager.initialize(\n" +
                            "  callbackDispatcher,\n" +
                            " )`" +
                            "\n" +
                            "\n" +
                            "The `callbackDispatcher` is a top level function. See example in repository.",
                    null
            )
            return
        }

        when (convertedCall) {
            is WorkManagerCall.RegisterTask.OneOffTask -> enqueueOneOffTask(context, convertedCall)
            is WorkManagerCall.RegisterTask.PeriodicTask -> enqueuePeriodicTask(context, convertedCall)
        }
        result.success()
    }

    private fun enqueuePeriodicTask(context: Context, convertedCall: WorkManagerCall.RegisterTask.PeriodicTask) {
        WM.enqueuePeriodicTask(context = context,
                uniqueName = convertedCall.uniqueName,
                dartTask = convertedCall.taskName,
                tag = convertedCall.tag,
                frequencyInSeconds = convertedCall.frequencyInSeconds,
                isInDebugMode = convertedCall.isInDebugMode,
                existingWorkPolicy = convertedCall.existingWorkPolicy,
                initialDelaySeconds = convertedCall.initialDelaySeconds,
                constraintsConfig = convertedCall.constraintsConfig,
                backoffPolicyConfig = convertedCall.backoffPolicyConfig,
                payload = convertedCall.payload
        )
    }

    private fun enqueueOneOffTask(context: Context, convertedCall: WorkManagerCall.RegisterTask.OneOffTask) {
        WM.enqueueOneOffTask(
                context = context,
                uniqueName = convertedCall.uniqueName,
                dartTask = convertedCall.taskName,
                tag = convertedCall.tag,
                isInDebugMode = convertedCall.isInDebugMode,
                existingWorkPolicy = convertedCall.existingWorkPolicy,
                initialDelaySeconds = convertedCall.initialDelaySeconds,
                constraintsConfig = convertedCall.constraintsConfig,
                backoffPolicyConfig = convertedCall.backoffPolicyConfig,
                payload = convertedCall.payload
        )
    }
}

private object UnregisterTaskHandler : CallHandler<WorkManagerCall.CancelTask> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.CancelTask, result: MethodChannel.Result) {
        when (convertedCall) {
            is WorkManagerCall.CancelTask.ByUniqueName -> WM.cancelByUniqueName(context, convertedCall.uniqueName)
            is WorkManagerCall.CancelTask.ByTag -> WM.cancelByTag(context, convertedCall.tag)
            WorkManagerCall.CancelTask.All -> WM.cancelAll(context)
        }
        result.success()
    }
}

private object UnknownTaskHandler : CallHandler<WorkManagerCall.Unknown> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.Unknown, result: MethodChannel.Result) {
        result.notImplemented()
    }
}

object WM {
    fun enqueueOneOffTask(context: Context,
                          uniqueName: String,
                          dartTask: String,
                          payload: String? = null,
                          tag: String? = null,
                          isInDebugMode: Boolean = false,
                          existingWorkPolicy: ExistingWorkPolicy = defaultOneOffExistingWorkPolicy,
                          initialDelaySeconds: Long = defaultInitialDelaySeconds,
                          constraintsConfig: Constraints = defaultConstraints,
                          backoffPolicyConfig: BackoffPolicyTaskConfig?
    ) {
        val oneOffTaskRequest = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
                .setInputData(buildTaskInputData(dartTask, isInDebugMode, payload))
                .setInitialDelay(initialDelaySeconds, TimeUnit.SECONDS)
                .setConstraints(constraintsConfig)
                .apply {
                    if (backoffPolicyConfig != null) {
                        setBackoffCriteria(
                                backoffPolicyConfig.backoffPolicy,
                                backoffPolicyConfig.backoffDelay,
                                TimeUnit.MILLISECONDS
                        )
                    }
                }
                .apply { tag?.let(::addTag) }
                .build()
        context.workManager()
                .enqueueUniqueWork(uniqueName, existingWorkPolicy, oneOffTaskRequest)
    }

    fun enqueuePeriodicTask(context: Context,
                            uniqueName: String,
                            dartTask: String,
                            payload: String? = null,
                            tag: String? = null,
                            frequencyInSeconds: Long = defaultPeriodicRefreshFrequencyInSeconds,
                            isInDebugMode: Boolean = false,
                            existingWorkPolicy: ExistingPeriodicWorkPolicy = defaultPeriodExistingWorkPolicy,
                            initialDelaySeconds: Long = defaultInitialDelaySeconds,
                            constraintsConfig: Constraints = defaultConstraints,
                            backoffPolicyConfig: BackoffPolicyTaskConfig?) {
        val periodicTaskRequest =
                PeriodicWorkRequest.Builder(BackgroundWorker::class.java, frequencyInSeconds, TimeUnit.SECONDS)
                        .setInputData(buildTaskInputData(dartTask, isInDebugMode, payload))
                        .setInitialDelay(initialDelaySeconds, TimeUnit.SECONDS)
                        .setConstraints(constraintsConfig)
                        .apply {
                            if (backoffPolicyConfig != null) {
                                setBackoffCriteria(
                                        backoffPolicyConfig.backoffPolicy,
                                        backoffPolicyConfig.backoffDelay,
                                        TimeUnit.MILLISECONDS
                                )
                            }
                        }
                        .apply { tag?.let(::addTag) }
                        .build()
        context.workManager()
                .enqueueUniquePeriodicWork(uniqueName, existingWorkPolicy, periodicTaskRequest)
    }

    private fun buildTaskInputData(dartTask: String, isInDebugMode: Boolean, payload: String?): Data {
        return Data.Builder()
                .putString(DART_TASK_KEY, dartTask)
                .putBoolean(IS_IN_DEBUG_MODE_KEY, isInDebugMode)
                .apply {
                    payload?.let {
                        putString(PAYLOAD_KEY, payload)
                    }
                }
                .build()
    }

    fun cancelByUniqueName(context: Context, uniqueWorkName: String) = context.workManager().cancelUniqueWork(uniqueWorkName)
    fun cancelByTag(context: Context, tag: String) = context.workManager().cancelAllWorkByTag(tag)
    fun cancelAll(context: Context) = context.workManager().cancelAllWork()
}
