package be.tramckrijte.workmanager

import android.content.Context
import androidx.work.*
import be.tramckrijte.workmanager.EchoingWorker.Companion.IS_IN_DEBUG_MODE
import be.tramckrijte.workmanager.EchoingWorker.Companion.VALUE_TO_ECHO_KEY
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Method
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
                is WorkManagerCall.RegisterTask.OneOffTask -> OneOffTaskHandler.handle(ctx, extractedCall, result)
                is WorkManagerCall.RegisterTask.PeriodicTask -> PeriodicTaskHandler.handle(ctx, extractedCall, result)
                is WorkManagerCall.CancelTask -> UnregisterTaskHandler.handle(ctx, extractedCall, result)
                is WorkManagerCall.Unknown -> UnknownTaskHandler.handle(ctx, extractedCall, result)
            }
}

private object InitializeHandler : CallHandler<WorkManagerCall.Initialize> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.Initialize, result: MethodChannel.Result) {
        SharedPreferenceHelper.saveCallbackDispatcherHandleKey(context, convertedCall.callbackDispatcherHandleKey)
        WorkManager.initialize(
                context,
                Configuration.Builder()
                        .setMinimumLoggingLevel(android.util.Log.INFO)
                        .build()
        )
        result.success()
    }
}

private object OneOffTaskHandler : CallHandler<WorkManagerCall.RegisterTask.OneOffTask> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.RegisterTask.OneOffTask, result: MethodChannel.Result) {
        val oneOffTaskRequest = OneTimeWorkRequest.Builder(EchoingWorker::class.java)
                .setInputData(Data.Builder().putAll(mapOf(VALUE_TO_ECHO_KEY to convertedCall.valueToReturn, IS_IN_DEBUG_MODE to convertedCall.isInDebugMode)).build())
                .setInitialDelay(convertedCall.initialDelaySeconds, TimeUnit.SECONDS)
                .setConstraints(convertedCall.constraintsConfig)
                .setBackoffCriteria(convertedCall.backoffPolicyConfig.backoffPolicy, convertedCall.backoffPolicyConfig.backoffDelay, TimeUnit.MILLISECONDS)
                .apply { convertedCall.tag?.let(::addTag) }
                .build()
        context.workManager().enqueueUniqueWork(convertedCall.uniqueName, convertedCall.existingWorkPolicy, oneOffTaskRequest)
        result.success()
    }
}

private object PeriodicTaskHandler : CallHandler<WorkManagerCall.RegisterTask.PeriodicTask> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.RegisterTask.PeriodicTask, result: MethodChannel.Result) {
        val periodicTaskRequest = PeriodicWorkRequest.Builder(EchoingWorker::class.java, convertedCall.frequencyInSeconds, TimeUnit.SECONDS)
                .setInputData(Data.Builder().putAll(mapOf(VALUE_TO_ECHO_KEY to convertedCall.valueToReturn, IS_IN_DEBUG_MODE to convertedCall.isInDebugMode)).build())
                .setInitialDelay(convertedCall.initialDelaySeconds, TimeUnit.SECONDS)
                .setConstraints(convertedCall.constraintsConfig)
                .setBackoffCriteria(convertedCall.backoffPolicyConfig.backoffPolicy, convertedCall.backoffPolicyConfig.backoffDelay, TimeUnit.MILLISECONDS)
                .apply { convertedCall.tag?.let(::addTag) }
                .build()
        context.workManager().enqueueUniquePeriodicWork(convertedCall.uniqueName, convertedCall.existingWorkPolicy, periodicTaskRequest)
        result.success()
    }
}

private object UnregisterTaskHandler : CallHandler<WorkManagerCall.CancelTask> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.CancelTask, result: MethodChannel.Result) {
        when (convertedCall) {
            is WorkManagerCall.CancelTask.ByUniqueName -> context.workManager().cancelUniqueWork(convertedCall.uniqueName)
            is WorkManagerCall.CancelTask.ByTag -> context.workManager().cancelAllWorkByTag(convertedCall.tag)
            WorkManagerCall.CancelTask.All -> context.workManager().cancelAllWork()
        }
        result.success()
    }
}

private object UnknownTaskHandler : CallHandler<WorkManagerCall.Unknown> {
    override fun handle(context: Context, convertedCall: WorkManagerCall.Unknown, result: MethodChannel.Result) {
        result.notImplemented()
    }
}