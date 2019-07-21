package be.tramckrijte.workmanager

import android.content.Context
import java.lang.IllegalStateException

object SharedPreferenceHelper {

    private const val SHARED_PREFS_FILE_NAME = "flutter_workmanager_plugin"
    private const val CALLBACK_DISPATCHER_HANDLE_KEY = "be.tramckrijte.workmanager.CALLBACK_DISPATCHER_HANDLE_KEY"
    private fun Context.prefs() = getSharedPreferences(SHARED_PREFS_FILE_NAME, Context.MODE_PRIVATE)

    fun saveCallbackDispatcherHandleKey(ctx: Context, callbackHandle: Long) {
        ctx.prefs()
                .edit()
                .putLong(CALLBACK_DISPATCHER_HANDLE_KEY, callbackHandle)
                .apply()
    }

    fun getCallbackHandle(ctx: Context): Long {
        if (!hasCallbackHandle(ctx)) {
            throw IllegalStateException("You have not properly initialized the Flutter WorkManager Package. You should ensure you have called the 'initialize' function first before registering any work.")
        }
        return ctx.prefs().getLong(CALLBACK_DISPATCHER_HANDLE_KEY, -1L)
    }

    private fun hasCallbackHandle(ctx: Context) = ctx.prefs().contains(CALLBACK_DISPATCHER_HANDLE_KEY)
}