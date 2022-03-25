import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  var displayLink : CADisplayLink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // https://github.com/flutter/flutter/issues/90675#issuecomment-930249845
    let controller = self.window.rootViewController as! FlutterViewController
    
    displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
    displayLink!.add(to: .current, forMode: .default)
      if #available(iOS 15.0, *) {
          displayLink!.preferredFrameRateRange = CAFrameRateRange(minimum:80, maximum:120, preferred:120)
      } else {
          // Fallback on earlier versions
      }
      
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // https://stackoverflow.com/a/66997677
  override func applicationWillResignActive(
    _ application: UIApplication
  ) {
    let secureKey = "flutter.useSecureMode"
    if UserDefaults.standard.bool(forKey: secureKey) {
      self.window.isHidden = true;
    }
  }
  override func applicationDidBecomeActive(
    _ application: UIApplication
  ) {
    self.window.isHidden = false;
  }


  @objc func displayLinkCallback(displaylink: CADisplayLink) {
      // Will be called once a frame has been built while matching desired frame rate
  }
}
