import AppKit

public final class StatusBarController: NSObject, @unchecked Sendable {
    public static let shared = StatusBarController()
    
    private var statusItem: NSStatusItem?
    
    private override init() {
        super.init()
    }
    
    public func setup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            if let button = self.statusItem?.button {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                let image = NSImage(systemSymbolName: "bolt.horizontal.circle.fill", accessibilityDescription: "NoxSnap")?
                    .withSymbolConfiguration(config) ??
                    NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "NoxSnap")?
                    .withSymbolConfiguration(config)
                image?.isTemplate = true
                button.image = image
                button.toolTip = "NoxSnap (Directional Magnetic Handoff)"
            }
            
            self.rebuildMenu()
        }
    }
    
    public func rebuildMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let menu = NSMenu()
            
            let headerItem = NSMenuItem(title: "⚡️ NoxSnap", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            
            let status = NoxSnapServer.shared.isRunning ? "🟢 Receiver: Online (Port \(NoxSnapServer.shared.port))" : "🔴 Receiver: Paused"
            let statusItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            menu.addItem(statusItem)
            
            let handoffItem = NSMenuItem(title: "🧭 Option A: Bezel Handoff Ready", action: nil, keyEquivalent: "")
            handoffItem.isEnabled = false
            menu.addItem(handoffItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let leftItem = NSMenuItem(title: "👈 Top-Left Bezel: Pull Mac ➔ Phone", action: nil, keyEquivalent: "")
            leftItem.isEnabled = false
            menu.addItem(leftItem)
            
            let rightItem = NSMenuItem(title: "👉 Top-Right Bezel: Push Phone ➔ Mac", action: nil, keyEquivalent: "")
            rightItem.isEnabled = false
            menu.addItem(rightItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let showWindow = NSMenuItem(title: "🎛️ Open NoxSnap Panel...", action: #selector(self.showWindowClicked), keyEquivalent: "p")
            showWindow.target = self
            menu.addItem(showWindow)
            
            let chimeItem = NSMenuItem(title: "🔔 Play Arrival Chime", action: #selector(self.chimeClicked), keyEquivalent: "c")
            chimeItem.target = self
            menu.addItem(chimeItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let quitItem = NSMenuItem(title: "Quit NoxSnap", action: #selector(self.quitClicked), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            
            self.statusItem?.menu = menu
        }
    }
    
    @objc private func showWindowClicked() {
        ControlWindowController.shared.show()
    }
    
    @objc private func chimeClicked() {
        SoundManager.shared.playChime()
    }
    
    @objc private func quitClicked() {
        NoxSnapServer.shared.stop()
        NSApplication.shared.terminate(nil)
    }
}
