import AppKit
import Foundation

public final class BrowserHandoffManager: @unchecked Sendable {
    public static let shared = BrowserHandoffManager()
    
    private var lastOpenedURL: String = ""
    private var lastOpenedTime: Date = Date.distantPast
    private let lock = NSLock()
    
    private init() {}
    
    // MARK: - Safe AppleScript Runner (Zero Duplicate Execution)
    @discardableResult
    private func runAppleScript(_ code: String) -> String? {
        var error: NSDictionary?
        if let script = NSAppleScript(source: code) {
            let output = script.executeAndReturnError(&error)
            if error == nil {
                // Succeeded! Return immediately and NEVER run duplicate osascript fallback
                return output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "ok"
            }
        }
        
        // Fallback only if NSAppleScript genuinely returned an error
        let proc = Process()
        let pipe = Pipe()
        proc.launchPath = "/usr/bin/osascript"
        proc.arguments = ["-e", code]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let res = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let r = res, !r.isEmpty {
                return r
            }
        } catch {}
        
        return nil
    }
    
    // MARK: - Active Browser URL Detection (Chrome, Safari, Arc, Brave, Edge)
    public func getActiveBrowserURL() -> String? {
        let apps = NSWorkspace.shared.runningApplications
        let frontId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        
        // 1. Check frontmost browser first if user is actively in one
        if frontId == "com.apple.Safari" {
            if let url = runAppleScript("tell application \"Safari\" to return URL of front document") { return url }
        } else if frontId == "com.google.Chrome" {
            if let url = runAppleScript("tell application \"Google Chrome\" to return URL of active tab of front window") { return url }
        } else if frontId == "company.thebrowser.Browser" {
            if let url = runAppleScript("tell application \"Arc\" to return URL of active tab of front window") { return url }
        } else if frontId == "com.brave.Browser" {
            if let url = runAppleScript("tell application \"Brave Browser\" to return URL of active tab of front window") { return url }
        } else if frontId == "com.microsoft.edgemac" {
            if let url = runAppleScript("tell application \"Microsoft Edge\" to return URL of active tab of front window") { return url }
        }
        
        // 2. Fallback to running browsers in priority order
        if apps.contains(where: { $0.bundleIdentifier == "com.google.Chrome" }) {
            if let url = runAppleScript("tell application \"Google Chrome\" to return URL of active tab of front window") {
                return url
            }
        }
        if apps.contains(where: { $0.bundleIdentifier == "com.apple.Safari" }) {
            if let url = runAppleScript("tell application \"Safari\" to return URL of front document") {
                return url
            }
        }
        if apps.contains(where: { $0.bundleIdentifier == "company.thebrowser.Browser" }) {
            if let url = runAppleScript("tell application \"Arc\" to return URL of active tab of front window") {
                return url
            }
        }
        if apps.contains(where: { $0.bundleIdentifier == "com.brave.Browser" }) {
            if let url = runAppleScript("tell application \"Brave Browser\" to return URL of active tab of front window") {
                return url
            }
        }
        if apps.contains(where: { $0.bundleIdentifier == "com.microsoft.edgemac" }) {
            if let url = runAppleScript("tell application \"Microsoft Edge\" to return URL of active tab of front window") {
                return url
            }
        }
        return nil
    }
    
    // MARK: - Safe, Powerful Browser URL Opening (Zero Audio Blast, Single Tab Guarantee)
    public func openURL(_ urlString: String, side: String = "right") {
        var final = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        final = final.replacingOccurrences(of: "\"", with: "")
        if !final.lowercased().hasPrefix("http://") && !final.lowercased().hasPrefix("https://") {
            final = "https://" + final
        }
        
        guard let url = URL(string: final) else { return }
        
        // De-duplicate: strictly prevent duplicate tabs opening within 2.5s
        lock.lock()
        let now = Date()
        let elapsed = now.timeIntervalSince(lastOpenedTime)
        if elapsed < 2.2 {
            print("⏳ Ignored rapid duplicate openURL for \(final) (elapsed: \(elapsed)s)")
            lock.unlock()
            return
        }
        lastOpenedURL = final
        lastOpenedTime = now
        lock.unlock()
        
        DispatchQueue.main.async {
            // 1. Trigger Apple-Grade Crystalline Water Repel Ripple Effect from Touched Side
            MagneticRepelOverlay.shared.triggerRepelEffect(side: side)
            
            // 2. Open via active/running browser with clean single tab creation
            let apps = NSWorkspace.shared.runningApplications
            let frontId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            
            if frontId == "com.apple.Safari" || (!apps.contains(where: { $0.bundleIdentifier == "com.google.Chrome" }) && apps.contains(where: { $0.bundleIdentifier == "com.apple.Safari" })) {
                let script = """
                tell application "Safari"
                    activate
                    if (count of windows) is 0 then
                        make new document with properties {URL:"\(final)"}
                    else
                        tell front window to make new tab with properties {URL:"\(final)"}
                    end if
                end tell
                """
                _ = self.runAppleScript(script)
            } else if frontId == "company.thebrowser.Browser" {
                let script = """
                tell application "Arc"
                    activate
                    open location "\(final)"
                end tell
                """
                _ = self.runAppleScript(script)
            } else if apps.contains(where: { $0.bundleIdentifier == "com.google.Chrome" }) {
                let script = """
                tell application "Google Chrome"
                    activate
                    if (count of windows) is 0 then
                        make new window
                        set URL of active tab of front window to "\(final)"
                    else
                        tell front window to make new tab with properties {URL:"\(final)"}
                    end if
                end tell
                """
                _ = self.runAppleScript(script)
            } else if apps.contains(where: { $0.bundleIdentifier == "com.brave.Browser" }) {
                let script = """
                tell application "Brave Browser"
                    activate
                    if (count of windows) is 0 then
                        make new window
                        set URL of active tab of front window to "\(final)"
                    else
                        tell front window to make new tab with properties {URL:"\(final)"}
                    end if
                end tell
                """
                _ = self.runAppleScript(script)
            } else if apps.contains(where: { $0.bundleIdentifier == "com.microsoft.edgemac" }) {
                let script = """
                tell application "Microsoft Edge"
                    activate
                    if (count of windows) is 0 then
                        make new window
                        set URL of active tab of front window to "\(final)"
                    else
                        tell front window to make new tab with properties {URL:"\(final)"}
                    end if
                end tell
                """
                _ = self.runAppleScript(script)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Safe Clipboard Handling
    public func copyToClipboard(_ text: String) {
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            MagneticRepelOverlay.shared.triggerRepelEffect(side: "right")
        }
    }
    
    public func getClipboardText() -> String {
        return NSPasteboard.general.string(forType: .string) ?? ""
    }
}
