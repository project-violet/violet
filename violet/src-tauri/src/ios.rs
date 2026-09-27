use objc2::{msg_send, runtime::AnyObject, sel};
use objc2_ui_kit::UIEdgeInsets;

// Called only by with_webview, on UIKit's main thread. These setters belong to
// TaoUIViewController, not private Apple APIs. Tao calls the public UIKit
// appearance-update methods from the setters.
pub fn viewer_fullscreen(webview: tauri::webview::PlatformWebview, enabled: bool) -> Result<(), String> {
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

        let () = msg_send![controller, setPrefersStatusBarHidden: enabled];
        let () = msg_send![controller, setPrefersHomeIndicatorAutoHidden: enabled];
        // Never inset the reader for system bars; viewport-fit=cover lets the
        // images reach the edges, while existing overlay CSS respects safe areas.
        // Restore UIKit's automatic inset calculation outside the viewer.
        let behavior: isize = if enabled { 2 } else { 0 };
        let () = msg_send![scroll, setContentInsetAdjustmentBehavior: behavior];
        if enabled {
            let zero = UIEdgeInsets { top: 0.0, left: 0.0, bottom: 0.0, right: 0.0 };
            let () = msg_send![scroll, setContentInset: zero];
        }
        let () = msg_send![view, setNeedsLayout];
        let () = msg_send![view, layoutIfNeeded];
    }
    Ok(())
}
