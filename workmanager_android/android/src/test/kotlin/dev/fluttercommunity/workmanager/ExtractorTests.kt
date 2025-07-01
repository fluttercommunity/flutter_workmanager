package dev.fluttercommunity.workmanager

import androidx.work.NetworkType
import androidx.work.OutOfQuotaPolicy
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Test

class ExtractorTests {
    @Test
    fun shouldParseOutOfQuotaPolicyFromCall() {
        val all =
            mapOf(
                null to null,
                "dropWorkRequest" to OutOfQuotaPolicy.DROP_WORK_REQUEST,
                "runAsNonExpeditedWorkRequest" to
                    OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST,
            )

        all.forEach { (dartString, wmConstant) ->
            val call =
                MethodCall(
                    "",
                    mapOf("outOfQuotaPolicy" to dartString),
                )
            assertEquals(Extractor.extractOutOfQuotaPolicyFromCall(call), wmConstant)
        }
    }

    @Test
    fun shouldParseNetworkTypeFromCall() {
        val all =
            mapOf(
                "unmetered" to NetworkType.UNMETERED,
                "metered" to NetworkType.METERED,
                "notRequired" to NetworkType.NOT_REQUIRED,
                "notRoaming" to NetworkType.NOT_ROAMING,
                "temporarilyUnmetered" to NetworkType.TEMPORARILY_UNMETERED,
                "connected" to NetworkType.CONNECTED,
            )

        all.forEach { (dartString, wmConstant) ->
            val call =
                MethodCall(
                    "",
                    mapOf(
                        "networkType" to dartString,
                    ),
                )
            val constraints = Extractor.extractConstraintConfigFromCall(call)

            assertEquals(constraints.requiredNetworkType, wmConstant)
        }
    }
}
