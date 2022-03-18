import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // https://stackoverflow.com/a/66997677
  override func applicationWillResignActive(
    _ application: UIApplication
  ) {
    let preferences = NSUserDefaults.standardUserDefaults()
    let secureKey = "useSecureMode"
    if preferences.objectForKey(secureKey) != nil {
      let secureMode = preferences.integerForKey(secureKey)
      if secureMode == true {
        self.window.isHidden = true;
      }
    }
  }
  override func applicationDidBecomeActive(
    _ application: UIApplication
  ) {
    self.window.isHidden = false;
  }
}
