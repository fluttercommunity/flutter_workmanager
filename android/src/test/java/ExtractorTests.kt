import androidx.work.NetworkType
import be.tramckrijte.workmanager.Extractor
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Test

class ExtractorTests {
    @Test
    fun shouldParseNetworkTypeFromCall() {
        val all = mapOf(
            "unmetered" to NetworkType.UNMETERED,
            "metered" to NetworkType.METERED,
            "not_required" to NetworkType.NOT_REQUIRED,
            "not_roaming" to NetworkType.NOT_ROAMING,
            "temporarily_unmetered" to NetworkType.TEMPORARILY_UNMETERED,
            "connected" to NetworkType.CONNECTED
        )

        all.forEach { (dartString, wmConstant) ->
            val call = MethodCall(
                "",
                mapOf(
                    "networkType" to dartString
                )
            )
            val constraints = Extractor.extractConstraintConfigFromCall(call)

            assertEquals(constraints.requiredNetworkType, wmConstant)
        }
    }
}
