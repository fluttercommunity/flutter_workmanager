package be.tramckrijte.workmanager

import android.os.Build
import android.util.Log
import androidx.work.*
import be.tramckrijte.workmanager.WorkManagerCall.CancelTask.ByTag.KEYS.UNREGISTER_TASK_TAG_KEY
import be.tramckrijte.workmanager.WorkManagerCall.CancelTask.ByUniqueName.KEYS.UNREGISTER_TASK_UNIQUE_NAME_KEY
import be.tramckrijte.workmanager.WorkManagerCall.Initialize.KEYS.INITIALIZE_TASK_CALL_HANDLE_KEY
import be.tramckrijte.workmanager.WorkManagerCall.Initialize.KEYS.INITIALIZE_TASK_IS_IN_DEBUG_MODE_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_BACK_OFF_POLICY_DELAY_MILLIS_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_BACK_OFF_POLICY_TYPE_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_CONSTRAINTS_BATTERY_NOT_LOW_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_CONSTRAINTS_CHARGING_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_CONSTRAINTS_DEVICE_IDLE_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_CONSTRAINTS_NETWORK_TYPE_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_CONSTRAINTS_STORAGE_NOT_LOW_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_EXISTING_WORK_POLICY_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_INITIAL_DELAY_SECONDS_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_PAYLOAD_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_IS_IN_DEBUG_MODE_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_NAME_VALUE_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_TAG_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.KEYS.REGISTER_TASK_UNIQUE_NAME_KEY
import be.tramckrijte.workmanager.WorkManagerCall.RegisterTask.PeriodicTask.KEYS.PERIODIC_TASK_FREQUENCY_SECONDS_KEY
import io.flutter.plugin.common.MethodCall
import kotlin.math.max

val defaultBackOffPolicy = BackoffPolicy.EXPONENTIAL
val defaultNetworkType = NetworkType.NOT_REQUIRED
val defaultOneOffExistingWorkPolicy = ExistingWorkPolicy.KEEP
val defaultPeriodExistingWorkPolicy = ExistingPeriodicWorkPolicy.KEEP
val defaultConstraints: Constraints = Constraints.NONE
const val defaultInitialDelaySeconds = 0L
const val defaultRequestedBackoffDelay = 0L
const val defaultPeriodicRefreshFrequencyInSeconds = PeriodicWorkRequest.MIN_PERIODIC_INTERVAL_MILLIS / 1000
const val logTag = "Extractor"

data class BackoffPolicyTaskConfig(val backoffPolicy: BackoffPolicy,
                                   private val requestedBackoffDelay: Long,
                                   private val minBackoffInMillis: Long,
                                   val backoffDelay: Long = max(minBackoffInMillis, requestedBackoffDelay))

sealed class WorkManagerCall {
    data class Initialize(val callbackDispatcherHandleKey: Long,
                          val isInDebugMode: Boolean) : WorkManagerCall() {
        companion object KEYS {
            const val INITIALIZE_TASK_IS_IN_DEBUG_MODE_KEY = "isInDebugMode"
            const val INITIALIZE_TASK_CALL_HANDLE_KEY = "callbackHandle"
        }
    }

    sealed class RegisterTask : WorkManagerCall() {
        abstract val isInDebugMode: Boolean
        abstract val uniqueName: String
        abstract val taskName: String
        abstract val tag: String?
        abstract val initialDelaySeconds: Long
        abstract val constraintsConfig: Constraints?
        abstract val payload: String?

        companion object KEYS {
            const val REGISTER_TASK_IS_IN_DEBUG_MODE_KEY = "isInDebugMode"
            const val REGISTER_TASK_UNIQUE_NAME_KEY = "uniqueName"
            const val REGISTER_TASK_NAME_VALUE_KEY = "taskName"
            const val REGISTER_TASK_TAG_KEY = "tag"
            const val REGISTER_TASK_EXISTING_WORK_POLICY_KEY = "existingWorkPolicy"

            const val REGISTER_TASK_CONSTRAINTS_NETWORK_TYPE_KEY = "networkType"
            const val REGISTER_TASK_CONSTRAINTS_BATTERY_NOT_LOW_KEY = "requiresBatteryNotLow"
            const val REGISTER_TASK_CONSTRAINTS_CHARGING_KEY = "requiresCharging"
            const val REGISTER_TASK_CONSTRAINTS_DEVICE_IDLE_KEY = "requiresDeviceIdle"
            const val REGISTER_TASK_CONSTRAINTS_STORAGE_NOT_LOW_KEY = "requiresStorageNotLow"

            const val REGISTER_TASK_INITIAL_DELAY_SECONDS_KEY = "initialDelaySeconds"

            const val REGISTER_TASK_BACK_OFF_POLICY_TYPE_KEY = "backoffPolicyType"
            const val REGISTER_TASK_BACK_OFF_POLICY_DELAY_MILLIS_KEY = "backoffDelayInMilliseconds"
            const val REGISTER_TASK_PAYLOAD_KEY = "inputData"
        }

        data class OneOffTask(override val isInDebugMode: Boolean,
                              override val uniqueName: String,
                              override val taskName: String,
                              override val tag: String? = null,
                              val existingWorkPolicy: ExistingWorkPolicy,
                              override val initialDelaySeconds: Long,
                              override val constraintsConfig: Constraints,
                              val backoffPolicyConfig: BackoffPolicyTaskConfig?,
                              override val payload: String? = null) : RegisterTask()

        data class PeriodicTask(override val isInDebugMode: Boolean,
                                override val uniqueName: String,
                                override val taskName: String,
                                override val tag: String? = null,
                                val existingWorkPolicy: ExistingPeriodicWorkPolicy,
                                val frequencyInSeconds: Long,
                                override val initialDelaySeconds: Long,
                                override val constraintsConfig: Constraints,
                                val backoffPolicyConfig: BackoffPolicyTaskConfig?,
                                override val payload: String? = null) : RegisterTask() {
            companion object KEYS {
                const val PERIODIC_TASK_FREQUENCY_SECONDS_KEY = "frequency"
            }
        }
    }

    sealed class CancelTask : WorkManagerCall() {
        data class ByUniqueName(val uniqueName: String) : CancelTask() {
            companion object KEYS {
                const val UNREGISTER_TASK_UNIQUE_NAME_KEY = "uniqueName"
            }
        }

        data class ByTag(val tag: String) : CancelTask() {
            companion object KEYS {
                const val UNREGISTER_TASK_TAG_KEY = "tag"
            }
        }

        object All : CancelTask()
    }

    object Unknown : WorkManagerCall()
}

private enum class TaskType(val minimumBackOffDelay: Long) {
    ONE_OFF(OneTimeWorkRequest.MIN_BACKOFF_MILLIS),
    PERIODIC(PeriodicWorkRequest.MIN_BACKOFF_MILLIS)
}

object Extractor {
    private enum class PossibleWorkManagerCall(val rawMethodName: String?) {
        INITIALIZE("initialize"),

        REGISTER_ONE_OFF_TASK("registerOneOffTask"),
        REGISTER_PERIODIC_TASK("registerPeriodicTask"),

        CANCEL_TASK_BY_UNIQUE_NAME("cancelTaskByUniqueName"),
        CANCEL_TASK_BY_TAG("cancelTaskByTag"),
        CANCEL_ALL("cancelAllTasks"),

        UNKNOWN(null);

        companion object {
            fun fromRawMethodName(methodName: String): PossibleWorkManagerCall =
                    values()
                            .filter { !it.rawMethodName.isNullOrEmpty() }
                            .firstOrNull { it.rawMethodName == methodName }
                            ?: UNKNOWN
        }
    }

    fun extractWorkManagerCallFromRawMethodName(call: MethodCall): WorkManagerCall =
            when (PossibleWorkManagerCall.fromRawMethodName(call.method)) {
                PossibleWorkManagerCall.INITIALIZE -> {
                    WorkManagerCall.Initialize(
                            call.argument<Long>(INITIALIZE_TASK_CALL_HANDLE_KEY)!!,
                            call.argument<Boolean>(INITIALIZE_TASK_IS_IN_DEBUG_MODE_KEY)!!
                    )
                }
                PossibleWorkManagerCall.REGISTER_ONE_OFF_TASK -> {
                    WorkManagerCall.RegisterTask.OneOffTask(
                            isInDebugMode = call.argument<Boolean>(REGISTER_TASK_IS_IN_DEBUG_MODE_KEY)!!,
                            uniqueName = call.argument<String>(REGISTER_TASK_UNIQUE_NAME_KEY)!!,
                            taskName = call.argument<String>(REGISTER_TASK_NAME_VALUE_KEY)!!,
                            tag = call.argument<String>(REGISTER_TASK_TAG_KEY),
                            existingWorkPolicy = extractExistingWorkPolicyFromCall(call),
                            initialDelaySeconds = extractInitialDelayFromCall(call),
                            constraintsConfig = extractConstraintConfigFromCall(call),
                            backoffPolicyConfig = extractBackoffPolicyConfigFromCall(call, TaskType.ONE_OFF),
                            payload = extractPayload(call)
                    )
                }
                PossibleWorkManagerCall.REGISTER_PERIODIC_TASK -> {
                    WorkManagerCall.RegisterTask.PeriodicTask(
                            isInDebugMode = call.argument<Boolean>(REGISTER_TASK_IS_IN_DEBUG_MODE_KEY)!!,
                            uniqueName = call.argument<String>(REGISTER_TASK_UNIQUE_NAME_KEY)!!,
                            taskName = call.argument<String>(REGISTER_TASK_NAME_VALUE_KEY)!!,
                            frequencyInSeconds = extractFrequencySecondsFromCall(call),
                            tag = call.argument<String>(REGISTER_TASK_TAG_KEY),
                            existingWorkPolicy = extractExistingPeriodicWorkPolicyFromCall(call),
                            initialDelaySeconds = extractInitialDelayFromCall(call),
                            constraintsConfig = extractConstraintConfigFromCall(call),
                            backoffPolicyConfig = extractBackoffPolicyConfigFromCall(call, TaskType.PERIODIC),
                            payload = extractPayload(call)
                    )
                }

                PossibleWorkManagerCall.CANCEL_TASK_BY_UNIQUE_NAME -> WorkManagerCall.CancelTask.ByUniqueName(call.argument(UNREGISTER_TASK_UNIQUE_NAME_KEY)!!)
                PossibleWorkManagerCall.CANCEL_TASK_BY_TAG -> WorkManagerCall.CancelTask.ByTag(call.argument(UNREGISTER_TASK_TAG_KEY)!!)
                PossibleWorkManagerCall.CANCEL_ALL -> WorkManagerCall.CancelTask.All

                PossibleWorkManagerCall.UNKNOWN -> WorkManagerCall.Unknown
            }

    private fun extractExistingWorkPolicyFromCall(call: MethodCall): ExistingWorkPolicy =
            try {
                ExistingWorkPolicy.valueOf(call.argument<String>(REGISTER_TASK_EXISTING_WORK_POLICY_KEY)!!.toUpperCase())
            } catch (ignored: Exception) {
                defaultOneOffExistingWorkPolicy
            }

    private fun extractExistingPeriodicWorkPolicyFromCall(call: MethodCall): ExistingPeriodicWorkPolicy =
            try {
                ExistingPeriodicWorkPolicy.valueOf(call.argument<String>(REGISTER_TASK_EXISTING_WORK_POLICY_KEY)!!.toUpperCase())
            } catch (ignored: Exception) {
                defaultPeriodExistingWorkPolicy
            }

    private fun extractFrequencySecondsFromCall(call: MethodCall): Long =
            call.argument<Int>(PERIODIC_TASK_FREQUENCY_SECONDS_KEY)?.toLong()
                    ?: defaultPeriodicRefreshFrequencyInSeconds

    private fun extractInitialDelayFromCall(call: MethodCall): Long =
            call.argument<Int>(REGISTER_TASK_INITIAL_DELAY_SECONDS_KEY)?.toLong()
                    ?: defaultInitialDelaySeconds

    private fun extractBackoffPolicyConfigFromCall(call: MethodCall, taskType: TaskType): BackoffPolicyTaskConfig? {
        if (call.argument<String?>(REGISTER_TASK_BACK_OFF_POLICY_TYPE_KEY) == null) {
            return null
        }

        val backoffPolicy = try {
            BackoffPolicy.valueOf(call.argument<String>(REGISTER_TASK_BACK_OFF_POLICY_TYPE_KEY)!!.toUpperCase())
        } catch (ignored: Exception) {
            defaultBackOffPolicy
        }

        val requestedBackoffDelay = call.argument<Int>(REGISTER_TASK_BACK_OFF_POLICY_DELAY_MILLIS_KEY)?.toLong()
                ?: defaultRequestedBackoffDelay
        val minimumBackOffDelay = taskType.minimumBackOffDelay

        return BackoffPolicyTaskConfig(
                backoffPolicy,
                requestedBackoffDelay,
                minimumBackOffDelay
        )
    }

    private fun extractConstraintConfigFromCall(call: MethodCall): Constraints {
        fun extractNetworkTypeFromCall(call: MethodCall) =
                try {
                    NetworkType.valueOf(call.argument<String>(REGISTER_TASK_CONSTRAINTS_NETWORK_TYPE_KEY)!!.toUpperCase())
                } catch (ignored: Exception) {
                    defaultNetworkType
                }

        val requestedNetworkType = extractNetworkTypeFromCall(call)
        val requiresBatteryNotLow = call.argument<Boolean>(REGISTER_TASK_CONSTRAINTS_BATTERY_NOT_LOW_KEY)
                ?: false
        val requiresCharging = call.argument<Boolean>(REGISTER_TASK_CONSTRAINTS_CHARGING_KEY)
                ?: false
        val requiresDeviceIdle = call.argument<Boolean>(REGISTER_TASK_CONSTRAINTS_DEVICE_IDLE_KEY)
                ?: false
        val requiresStorageNotLow = call.argument<Boolean>(REGISTER_TASK_CONSTRAINTS_STORAGE_NOT_LOW_KEY)
                ?: false
        return Constraints.Builder()
                .setRequiredNetworkType(requestedNetworkType)
                .setRequiresBatteryNotLow(requiresBatteryNotLow)
                .setRequiresCharging(requiresCharging)
                .setRequiresStorageNotLow(requiresStorageNotLow)
                .apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        setRequiresDeviceIdle(requiresDeviceIdle)
                    }
                }
                .build()
    }

    private fun extractPayload(call: MethodCall): String? {
        return call.argument<String>(REGISTER_TASK_PAYLOAD_KEY)
    }
}
