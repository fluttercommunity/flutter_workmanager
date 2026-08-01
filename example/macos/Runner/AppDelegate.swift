import Cocoa
import FlutterMacOS
import workmanager_apple

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Registers plugins with the headless Flutter engine that workmanager
    // spawns when a scheduled task runs.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      RegisterGeneratedPlugins(registry: registry)
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
