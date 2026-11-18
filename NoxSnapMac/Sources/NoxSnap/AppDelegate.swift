import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        StatusBarController.shared.setup()
        NoxSnapServer.shared.start()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        NoxSnapServer.shared.stop()
    }
}
