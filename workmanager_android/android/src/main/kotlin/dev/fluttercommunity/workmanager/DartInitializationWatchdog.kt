package dev.fluttercommunity.workmanager

import android.os.Handler
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Bounds the Dart engine initialization handshake of a [BackgroundWorker].
 *
 * The worker's result future is only resolved once the Dart side acknowledges
 * `backgroundChannelInitialized`. If the engine fails to start the Dart
 * isolate, or the acknowledgement is lost, the worker would otherwise stay in
 * the RUNNING state forever (see #732). This watchdog fires [timeoutAction]
 * when the acknowledgement does not arrive within [timeoutMillis].
 *
 * [arm] and [disarm] are idempotent and safe to call from any thread: the
 * action fires at most once, and only while the watchdog is armed.
 */
internal class DartInitializationWatchdog(
    private val handler: Handler,
    private val timeoutMillis: Long,
    private val timeoutAction: () -> Unit,
) {
    private val armed = AtomicBoolean(false)
    private val timeoutRunnable =
        Runnable {
            if (armed.compareAndSet(true, false)) {
                timeoutAction()
            }
        }

    /** Starts the countdown. No-op if already armed or already fired. */
    fun arm() {
        if (armed.compareAndSet(false, true)) {
            handler.postDelayed(timeoutRunnable, timeoutMillis)
        }
    }

    /** Cancels the countdown. No-op if not armed or already fired. */
    fun disarm() {
        if (armed.compareAndSet(true, false)) {
            handler.removeCallbacks(timeoutRunnable)
        }
    }
}
