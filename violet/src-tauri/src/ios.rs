use objc2::{msg_send, runtime::AnyObject, sel};
use objc2_ui_kit::UIEdgeInsets;

// Called only by with_webview, on UIKit's main thread. These setters belong to
// TaoUIViewController, not private Apple APIs. Tao calls the public UIKit
// appearance-update methods from the setters.
pub fn viewer_fullscreen(webview: tauri::webview::PlatformWebview, enabled: bool, dark: bool) -> Result<(), String> {
    unsafe {
        let controller = (webview.view_controller() as *mut AnyObject)
            .as_ref().ok_or("Missing iOS view controller")?;
        let status_supported: bool = msg_send![controller, respondsToSelector: sel!(setPrefersStatusBarHidden:)];
        let home_supported: bool = msg_send![controller, respondsToSelector: sel!(setPrefersHomeIndicatorAutoHidden:)];
        if !status_supported || !home_supported {
            return Err("The iOS view controller does not support reader fullscreen".into());
        }
        let view = (webview.inner() as *mut AnyObject)
            .as_ref().ok_or("Missing iOS webview")?;
        let scroll: *mut AnyObject = msg_send![view, scrollView];
        let scroll = scroll.as_ref().ok_or("Missing iOS scroll view")?;

        // Keep status-bar contrast consistent with the web theme (the reader
        // itself is always dark), even when it differs from the system theme.
        let style: isize = if enabled || dark { 2 } else { 1 };
        let () = msg_send![controller, setOverrideUserInterfaceStyle: style];
        let () = msg_send![controller, setPrefersStatusBarHidden: enabled];
        let () = msg_send![controller, setPrefersHomeIndicatorAutoHidden: enabled];
        // CSS owns safe areas on every route, not just in the reader. Switching
        // between Automatic and Never while changing viewport-fit races WebKit's
        // layout and can leave a second scrollable inset above/below the page.
        let () = msg_send![scroll, setContentInsetAdjustmentBehavior: 2_isize];
        let zero = UIEdgeInsets { top: 0.0, left: 0.0, bottom: 0.0, right: 0.0 };
        let () = msg_send![scroll, setContentInset: zero];
        // iOS 26+ otherwise adds a native edge blur over our HTML header/nav.
        // Check availability so this still runs on the minimum supported iOS.
        for selector in [sel!(topEdgeEffect), sel!(bottomEdgeEffect)] {
            let supported: bool = msg_send![scroll, respondsToSelector: selector];
            if supported {
                let effect: *mut AnyObject = msg_send![scroll, performSelector: selector];
                if let Some(effect) = effect.as_ref() {
                    let () = msg_send![effect, setHidden: true];
                }
            }
        }
        let () = msg_send![view, setNeedsLayout];
        let () = msg_send![view, layoutIfNeeded];
    }
    Ok(())
}
