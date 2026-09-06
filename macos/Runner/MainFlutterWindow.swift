import Cocoa
import FlutterMacOS
import IOKit.pwr_mgt

class MainFlutterWindow: NSWindow {
  private var wakeLockAssertion: IOPMAssertionID = 0
  private var hasWakeLockAssertion = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    _registerWakeLockChannel(flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func _registerWakeLockChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "cohort.session/wake_lock",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setEnabled" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let enabled = (call.arguments as? Bool) ?? false
      self?._setWakeLock(enabled)
      result(nil)
    }
  }

  private func _setWakeLock(_ enabled: Bool) {
    if enabled {
      if hasWakeLockAssertion {
        return
      }
      let status = IOPMAssertionCreateWithName(
        kIOPMAssertionTypeNoDisplaySleep as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        "Cohort circuit timer" as CFString,
        &wakeLockAssertion
      )
      hasWakeLockAssertion = status == kIOReturnSuccess
      return
    }
    if hasWakeLockAssertion {
      IOPMAssertionRelease(wakeLockAssertion)
      hasWakeLockAssertion = false
      wakeLockAssertion = 0
    }
  }
}
