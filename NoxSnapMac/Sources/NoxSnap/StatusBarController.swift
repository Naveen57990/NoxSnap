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
            
            let rippleSubmenu = NSMenu()
            let currentPref = UserDefaults.standard.string(forKey: "NoxSnapRippleSidePref") ?? "right"
            
            let optRight = NSMenuItem(title: "👉 Top-Right Bezel (Default)", action: #selector(self.setSideRight), keyEquivalent: "")
            optRight.target = self
            optRight.state = (currentPref == "right") ? .on : .off
            rippleSubmenu.addItem(optRight)
            
            let optLeft = NSMenuItem(title: "👈 Top-Left Bezel", action: #selector(self.setSideLeft), keyEquivalent: "")
            optLeft.target = self
            optLeft.state = (currentPref == "left") ? .on : .off
            rippleSubmenu.addItem(optLeft)
            
            let optBoth = NSMenuItem(title: "🌊 Both Corners (Dual Shockwave)", action: #selector(self.setSideBoth), keyEquivalent: "")
            optBoth.target = self
            optBoth.state = (currentPref == "both") ? .on : .off
            rippleSubmenu.addItem(optBoth)
            
            let optInvert = NSMenuItem(title: "🔄 Invert Phone Direction", action: #selector(self.setSideInvert), keyEquivalent: "")
            optInvert.target = self
            optInvert.state = (currentPref == "invert") ? .on : .off
            rippleSubmenu.addItem(optInvert)
            
            let optPhone = NSMenuItem(title: "📱 Auto (From Phone)", action: #selector(self.setSidePhone), keyEquivalent: "")
            optPhone.target = self
            optPhone.state = (currentPref == "phone") ? .on : .off
            rippleSubmenu.addItem(optPhone)
            
            let rippleMenuParent = NSMenuItem(title: "🌊 Water Ripple Origin", action: nil, keyEquivalent: "")
            rippleMenuParent.submenu = rippleSubmenu
            menu.addItem(rippleMenuParent)
            
            let testWave = NSMenuItem(title: "⚡️ Test Water Ripple Now", action: #selector(self.testWaveClicked), keyEquivalent: "t")
            testWave.target = self
            menu.addItem(testWave)
            
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
    
    @objc private func setSideRight() {
        UserDefaults.standard.set("right", forKey: "NoxSnapRippleSidePref")
        rebuildMenu()
        MagneticRepelOverlay.shared.triggerRepelEffect(side: "right")
    }
    
    @objc private func setSideLeft() {
        UserDefaults.standard.set("left", forKey: "NoxSnapRippleSidePref")
        rebuildMenu()
        MagneticRepelOverlay.shared.triggerRepelEffect(side: "left")
    }
    
    @objc private func setSideBoth() {
        UserDefaults.standard.set("both", forKey: "NoxSnapRippleSidePref")
        rebuildMenu()
        MagneticRepelOverlay.shared.triggerRepelEffect(side: "both")
    }
    
    @objc private func setSideInvert() {
        UserDefaults.standard.set("invert", forKey: "NoxSnapRippleSidePref")
        rebuildMenu()
    }
    
    @objc private func setSidePhone() {
        UserDefaults.standard.set("phone", forKey: "NoxSnapRippleSidePref")
        rebuildMenu()
    }
    
    @objc private func testWaveClicked() {
        let pref = UserDefaults.standard.string(forKey: "NoxSnapRippleSidePref") ?? "right"
        let side = (pref == "both") ? "both" : ((pref == "left") ? "left" : "right")
        MagneticRepelOverlay.shared.triggerRepelEffect(side: side)
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
