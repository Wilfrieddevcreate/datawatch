package net.alopro.datawatch

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import net.alopro.datawatch.device.DeviceChannel
import net.alopro.datawatch.usage.DataUsageChannel

class MainActivity : FlutterActivity() {
    private var usageChannel: DataUsageChannel? = null
    private var deviceChannel: DeviceChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        usageChannel = DataUsageChannel(this, messenger)
        deviceChannel = DeviceChannel(this, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        usageChannel?.dispose()
        deviceChannel?.dispose()
        usageChannel = null
        deviceChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        deviceChannel?.onRequestPermissionsResult(requestCode, grantResults)
    }
}
