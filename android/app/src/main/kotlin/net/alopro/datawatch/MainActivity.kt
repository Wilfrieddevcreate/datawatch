package net.alopro.datawatch

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import net.alopro.datawatch.usage.DataUsageChannel

class MainActivity : FlutterActivity() {
    private var usageChannel: DataUsageChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usageChannel = DataUsageChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        usageChannel?.dispose()
        usageChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
