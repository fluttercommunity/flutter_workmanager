package dev.fluttercommunity.workmanager

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.WorkInfo
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.pigeon.WorkmanagerFlutterApi
import io.flutter.plugin.common.BinaryMessenger
import java.util.Collections

/**
 * Routes progress updates from running background tasks back to the app.
 *
 * The write side is the running [BackgroundWorker]: it calls
 * `setProgressAsync(...)` (so the progress is persisted in WorkManager and
 * queryable through [WorkInfo]) and then reports the unique name here.
 *
 * The read side observes WorkManager's `getWorkInfosForUniqueWorkLiveData`
 * for that unique name and forwards every progress change to the app through
 * [WorkmanagerFlutterApi.onProgressUpdate] on the app-facing messenger.
 *
 * Observation is deliberately driven by [WorkManager]'s own work-info
 * database rather than by forwarding the reported map directly: the app then
 * receives exactly what WorkManager stores, and the first observation
 * delivers the latest progress even for a task that was already running when
 * the app (re)started.
 *
 * Android-only: on other platforms there is no native equivalent and this
 * coordinator is never wired up.
 */
object ProgressUpdateCoordinator {
    /**
     * The messenger of the engine the app talks to (the engine that called
     * `initialize` or `setProgressListener`). Progress events are forwarded
     * on this messenger; `null` means the app is not listening (or explicitly
     * unregistered) and no observation takes place.
     */
    @Volatile
    private var appMessenger: BinaryMessenger? = null

    private val observedUniqueNames = Collections.synchronizedSet(mutableSetOf<String>())

    /**
     * (Re)binds the app-facing messenger.
     *
     * Called when the app initializes the plugin and when it (un)registers a
     * progress listener, always on the engine the app talks to.
     */
    fun setAppMessenger(
        enabled: Boolean,
        messenger: BinaryMessenger,
    ) {
        appMessenger = if (enabled) messenger else null
    }

    /**
     * Called whenever a running task reports progress.
     *
     * Ensures the unique name's work info is observed and its progress is
     * forwarded to the app. Without an app-facing messenger there is nobody
     * to forward to, so nothing is registered (and [context] may be `null`
     * in unit tests).
     */
    fun onProgressReported(
        context: Context?,
        uniqueName: String,
    ) {
        val messenger = appMessenger ?: return
        if (!observedUniqueNames.add(uniqueName)) {
            return
        }

        val workManager = WorkManager.getInstance(context?.applicationContext ?: return)

        // LiveData observation must be registered on the main thread.
        Handler(Looper.getMainLooper()).post {
            workManager.getWorkInfosForUniqueWorkLiveData(uniqueName).observeForever { workInfos ->
                val running = workInfos?.firstOrNull { it.state == WorkInfo.State.RUNNING } ?: return@observeForever
                val progress = running.progress
                if (progress.keyValueMap.isEmpty()) {
                    return@observeForever
                }

                val currentMessenger = appMessenger ?: return@observeForever
                val decodedProgress = decodePayload(progress.keyValueMap)
                WorkmanagerFlutterApi(currentMessenger)
                    .onProgressUpdate(uniqueName, decodedProgress as Map<String?, Any?>) {
                        // The Dart side acknowledges or reports an error; there
                        // is nothing to act on here.
                    }
            }
        }
    }
}
